//
//  MetalRenderer.swift
//  NesCaster
//
//  High-performance Metal renderer for NES emulation
//  Features:
//  - 4K upscaling with integer scaling (pixel-perfect)
//  - 120fps frame interpolation
//  - CRT effects (scanlines, curvature, bloom)
//  - Sub-frame latency rendering
//  - Performance metrics
//

import Metal
import MetalKit
import simd

// MARK: - Scaling Mode

enum ScalingMode: Int, CaseIterable, Identifiable {
    case integer = 0     // Pixel-perfect integer scaling
    case smooth = 1      // Bilinear filtering
    case crt = 2         // CRT simulation
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .integer: return "Pixel Perfect"
        case .smooth: return "Smooth"
        case .crt: return "CRT"
        }
    }
    
    var description: String {
        switch self {
        case .integer: return "Sharp pixels, no filtering"
        case .smooth: return "Bilinear filtering for smooth edges"
        case .crt: return "Classic CRT monitor effects"
        }
    }
}

// MARK: - Renderer Configuration

struct RendererConfig {
    var targetResolution: SIMD2<Int32> = [3840, 2160]  // 4K
    var targetFrameRate: Int = 120
    
    // Scaling
    var scalingMode: ScalingMode = .integer
    var useIntegerScaling: Bool = true
    
    // Overscan (pixels to crop)
    var overscanTop: Int = 8
    var overscanBottom: Int = 8
    var overscanLeft: Int = 0
    var overscanRight: Int = 0
    var useOverscan: Bool = true
    
    // Frame interpolation
    var enableFrameInterpolation: Bool = true
    
    // CRT effects (only used when scalingMode == .crt)
    var scanlineIntensity: Float = 0.3
    var curvature: Float = 0.02
    var vignetteStrength: Float = 0.2
    var bloomStrength: Float = 0.15
}

// MARK: - Performance Metrics

struct PerformanceMetrics {
    var fps: Double = 0
    var frameTime: Double = 0        // ms
    var renderTime: Double = 0       // ms
    var gpuTime: Double = 0          // ms (if available)
    var frameCount: Int = 0
    var droppedFrames: Int = 0
    
    // Rolling averages
    private var frameTimeSamples: [Double] = []
    private let maxSamples = 60
    
    mutating func recordFrame(time: Double) {
        frameTimeSamples.append(time)
        if frameTimeSamples.count > maxSamples {
            frameTimeSamples.removeFirst()
        }
        
        if !frameTimeSamples.isEmpty {
            let avgTime = frameTimeSamples.reduce(0, +) / Double(frameTimeSamples.count)
            fps = 1.0 / avgTime
            frameTime = avgTime * 1000.0 // Convert to ms
        }
        frameCount += 1
    }
}

// MARK: - Shader Uniforms (must match Metal struct)

struct ShaderUniforms {
    var inputSize: SIMD2<Float>
    var outputSize: SIMD2<Float>
    var time: Float
    var interpolationFactor: Float
    
    var scalingMode: Int32
    var useOverscan: Int32
    var overscan: SIMD4<Float>  // top, bottom, left, right
    
    var scanlineIntensity: Float
    var curvature: Float
    var vignetteStrength: Float
    var bloomStrength: Float
}

// MARK: - Metal Renderer

class MetalRenderer: NSObject, MTKViewDelegate, ObservableObject {
    
    // Metal objects
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var interpolationPipelineState: MTLRenderPipelineState?
    private var computePipeline: MTLComputePipelineState?
    private var scanlinePipeline: MTLComputePipelineState?
    
    // Textures
    private var nesFrameTexture: MTLTexture!          // Raw NES output (256x240)
    private var scaledTexture: MTLTexture?            // Upscaled texture
    private var previousFrameTexture: MTLTexture?     // For interpolation
    private var intermediateTexture: MTLTexture?      // For multi-pass effects
    
    // Buffers
    private var vertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    
    // Configuration
    @Published var config = RendererConfig()
    
    // Performance tracking
    @Published var metrics = PerformanceMetrics()
    private var lastFrameTime: CFTimeInterval = 0
    private var hasExternalFrame = false
    private var showMetrics = false
    
    // Run-ahead state
    private var runAheadFrames: Int = 0
    private var runAheadBuffer: [[UInt8]] = []
    
    // MARK: - NES Display Constants
    
    static let nesWidth = 256
    static let nesHeight = 240
    static let nesAspectRatio: Float = 256.0 / 240.0 * (8.0 / 7.0) // PAR corrected
    
    // Computed scale factor
    var currentScaleFactor: Int {
        let scaleX = Int(config.targetResolution.x) / Self.nesWidth
        let scaleY = Int(config.targetResolution.y) / Self.nesHeight
        return max(1, min(scaleX, scaleY))
    }
    
    // MARK: - Initialization
    
    init?(mtkView: MTKView) {
        guard let device = mtkView.device else {
            print("❌ Metal device not available")
            return nil
        }
        
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            print("❌ Failed to create command queue")
            return nil
        }
        self.commandQueue = queue
        
        super.init()
        
        setupMetal(mtkView: mtkView)
        createTextures()
        createBuffers()
        
        print("✅ Metal Renderer initialized")
        print("   Device: \(device.name)")
        print("   Max threads per group: \(device.maxThreadsPerThreadgroup)")
        print("   Integer scale: \(currentScaleFactor)x")
    }
    
    // MARK: - Setup
    
    private func setupMetal(mtkView: MTKView) {
        // Configure view for low latency
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false  // Need read access for effects
        mtkView.preferredFramesPerSecond = config.targetFrameRate
        mtkView.presentsWithTransaction = false
        
        // Create shader library
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load Metal shader library")
        }
        
        // Main render pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create render pipeline: \(error)")
        }
        
        // Frame interpolation pipeline
        if let interpolationFunction = library.makeFunction(name: "interpolationFragmentShader") {
            let interpolationDescriptor = MTLRenderPipelineDescriptor()
            interpolationDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
            interpolationDescriptor.fragmentFunction = interpolationFunction
            interpolationDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
            
            do {
                interpolationPipelineState = try device.makeRenderPipelineState(descriptor: interpolationDescriptor)
            } catch {
                print("⚠️ Interpolation pipeline creation failed: \(error)")
            }
        }
        
        // Compute pipelines
        if let upscaleFunction = library.makeFunction(name: "upscaleKernel") {
            do {
                computePipeline = try device.makeComputePipelineState(function: upscaleFunction)
            } catch {
                print("⚠️ Upscale compute pipeline creation failed: \(error)")
            }
        }
        
        if let scanlineFunction = library.makeFunction(name: "scanlineKernel") {
            do {
                scanlinePipeline = try device.makeComputePipelineState(function: scanlineFunction)
            } catch {
                print("⚠️ Scanline compute pipeline creation failed: \(error)")
            }
        }
    }
    
    private func createTextures() {
        // NES frame texture (raw 256x240)
        let nesDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Self.nesWidth,
            height: Self.nesHeight,
            mipmapped: false
        )
        nesDescriptor.usage = [.shaderRead, .shaderWrite]
        nesDescriptor.storageMode = .shared
        
        nesFrameTexture = device.makeTexture(descriptor: nesDescriptor)
        nesFrameTexture.label = "NES Frame"
        
        // Previous frame for interpolation
        previousFrameTexture = device.makeTexture(descriptor: nesDescriptor)
        previousFrameTexture?.label = "Previous Frame"
        
        // Scaled/intermediate textures
        let outputWidth = Int(config.targetResolution.x)
        let outputHeight = Int(config.targetResolution.y)
        
        let scaledDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: outputWidth,
            height: outputHeight,
            mipmapped: false
        )
        scaledDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        scaledDescriptor.storageMode = .private
        
        scaledTexture = device.makeTexture(descriptor: scaledDescriptor)
        scaledTexture?.label = "Scaled Output"
        
        intermediateTexture = device.makeTexture(descriptor: scaledDescriptor)
        intermediateTexture?.label = "Intermediate"
    }
    
    private func createBuffers() {
        // Full-screen quad vertices (position + texcoord)
        let vertices: [Float] = [
            // Position (x, y)   TexCoord (u, v)
            -1.0, -1.0,          0.0, 1.0,
             1.0, -1.0,          1.0, 1.0,
            -1.0,  1.0,          0.0, 0.0,
             1.0,  1.0,          1.0, 0.0,
        ]
        
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<Float>.stride,
            options: .storageModeShared
        )
        vertexBuffer.label = "Vertices"
        
        // Uniform buffer
        uniformBuffer = device.makeBuffer(
            length: MemoryLayout<ShaderUniforms>.stride,
            options: .storageModeShared
        )
        uniformBuffer.label = "Uniforms"
        
        updateUniforms(outputSize: CGSize(
            width: CGFloat(config.targetResolution.x),
            height: CGFloat(config.targetResolution.y)
        ))
    }
    
    private func updateUniforms(outputSize: CGSize, interpolationFactor: Float = 0) {
        var uniforms = ShaderUniforms(
            inputSize: SIMD2<Float>(Float(Self.nesWidth), Float(Self.nesHeight)),
            outputSize: SIMD2<Float>(Float(outputSize.width), Float(outputSize.height)),
            time: Float(CACurrentMediaTime()),
            interpolationFactor: interpolationFactor,
            scalingMode: Int32(config.scalingMode.rawValue),
            useOverscan: config.useOverscan ? 1 : 0,
            overscan: SIMD4<Float>(
                Float(config.overscanTop),
                Float(config.overscanBottom),
                Float(config.overscanLeft),
                Float(config.overscanRight)
            ),
            scanlineIntensity: config.scanlineIntensity,
            curvature: config.curvature,
            vignetteStrength: config.vignetteStrength,
            bloomStrength: config.bloomStrength
        )
        
        uniformBuffer.contents().copyMemory(
            from: &uniforms,
            byteCount: MemoryLayout<ShaderUniforms>.stride
        )
    }
    
    // MARK: - Frame Update
    
    /// Call this when NES core produces a new frame
    func updateFrame(pixelData: UnsafePointer<UInt8>) {
        // Store previous frame for interpolation
        if config.enableFrameInterpolation,
           let prevTex = previousFrameTexture {
            // Copy current to previous
            if let commandBuffer = commandQueue.makeCommandBuffer(),
               let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                blitEncoder.copy(from: nesFrameTexture, to: prevTex)
                blitEncoder.endEncoding()
                commandBuffer.commit()
            }
        }
        
        hasExternalFrame = true
        
        // Copy NES frame to texture
        let region = MTLRegion(
            origin: MTLOrigin(x: 0, y: 0, z: 0),
            size: MTLSize(width: Self.nesWidth, height: Self.nesHeight, depth: 1)
        )
        
        nesFrameTexture.replace(
            region: region,
            mipmapLevel: 0,
            withBytes: pixelData,
            bytesPerRow: Self.nesWidth * 4
        )
    }
    
    /// Update frame from Data (for run-ahead)
    func updateFrame(data: Data) {
        data.withUnsafeBytes { ptr in
            if let basePtr = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                updateFrame(pixelData: basePtr)
            }
        }
    }
    
    // MARK: - Run-Ahead Support
    
    /// Set number of frames to run ahead for input latency reduction
    func setRunAheadFrames(_ frames: Int) {
        runAheadFrames = min(frames, 4) // Cap at 4 frames
        runAheadBuffer = Array(repeating: [], count: runAheadFrames)
    }
    
    // MARK: - Configuration Updates
    
    func setScalingMode(_ mode: ScalingMode) {
        config.scalingMode = mode
    }
    
    func setFrameInterpolation(enabled: Bool) {
        config.enableFrameInterpolation = enabled
    }
    
    func setCRTSettings(scanlines: Float, curvature: Float, vignette: Float, bloom: Float) {
        config.scanlineIntensity = scanlines
        config.curvature = curvature
        config.vignetteStrength = vignette
        config.bloomStrength = bloom
    }
    
    func setOverscan(top: Int, bottom: Int, left: Int, right: Int, enabled: Bool) {
        config.overscanTop = top
        config.overscanBottom = bottom
        config.overscanLeft = left
        config.overscanRight = right
        config.useOverscan = enabled
    }
    
    // MARK: - Performance Metrics
    
    func toggleMetricsDisplay() {
        showMetrics.toggle()
    }
    
    func getMetrics() -> PerformanceMetrics {
        return metrics
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        config.targetResolution = SIMD2<Int32>(Int32(size.width), Int32(size.height))
        createTextures()
        print("📐 Drawable size changed: \(Int(size.width))x\(Int(size.height))")
        print("   New integer scale: \(currentScaleFactor)x")
    }
    
    func draw(in view: MTKView) {
        let renderStartTime = CACurrentMediaTime()
        
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Calculate timing
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        
        // Update metrics
        if lastFrameTime > 0 {
            metrics.recordFrame(time: deltaTime)
        }
        lastFrameTime = currentTime
        
        // Calculate interpolation factor for 120fps from 60fps source
        let interpolationFactor: Float
        if config.enableFrameInterpolation && config.targetFrameRate > 60 {
            interpolationFactor = Float(deltaTime * 60.0).truncatingRemainder(dividingBy: 1.0)
        } else {
            interpolationFactor = 1.0
        }
        
        // Update uniforms
        updateUniforms(
            outputSize: view.drawableSize,
            interpolationFactor: interpolationFactor
        )
        
        // Choose pipeline based on interpolation
        let shouldInterpolate = config.enableFrameInterpolation && 
                               interpolationPipelineState != nil &&
                               previousFrameTexture != nil &&
                               interpolationFactor < 0.9
        
        // Render
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        if shouldInterpolate, let interpPipeline = interpolationPipelineState {
            // Use interpolation shader
            encoder.setRenderPipelineState(interpPipeline)
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.setFragmentTexture(nesFrameTexture, index: 0)
            encoder.setFragmentTexture(previousFrameTexture, index: 1)
        } else {
            // Standard render
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(nesFrameTexture, index: 0)
            encoder.setFragmentTexture(previousFrameTexture, index: 1)
        }
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        
        // Track render time
        metrics.renderTime = (CACurrentMediaTime() - renderStartTime) * 1000.0
    }
}

// MARK: - Renderer Configuration Extension

extension MetalRenderer {
    
    /// Get current configuration summary
    var configurationSummary: String {
        let resolution = "\(config.targetResolution.x)x\(config.targetResolution.y)"
        let scale = "\(currentScaleFactor)x integer scale"
        let mode = config.scalingMode.displayName
        let fps = "\(config.targetFrameRate)fps"
        let interp = config.enableFrameInterpolation ? "interpolation on" : "interpolation off"
        
        return "\(resolution) @ \(fps), \(scale), \(mode), \(interp)"
    }
    
    /// Apply preset configuration
    func applyPreset(_ preset: RenderPreset) {
        switch preset {
        case .performance:
            config.scalingMode = .integer
            config.enableFrameInterpolation = false
            config.targetFrameRate = 60
            
        case .balanced:
            config.scalingMode = .integer
            config.enableFrameInterpolation = true
            config.targetFrameRate = 120
            
        case .quality:
            config.scalingMode = .integer
            config.enableFrameInterpolation = true
            config.targetFrameRate = 120
            
        case .retro:
            config.scalingMode = .crt
            config.enableFrameInterpolation = false
            config.targetFrameRate = 60
            config.scanlineIntensity = 0.4
            config.curvature = 0.03
            config.vignetteStrength = 0.25
            config.bloomStrength = 0.2
        }
    }
}

// MARK: - Render Presets

enum RenderPreset: String, CaseIterable, Identifiable {
    case performance = "Performance"
    case balanced = "Balanced"
    case quality = "Quality"
    case retro = "Retro CRT"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .performance: return "60fps, no effects, lowest latency"
        case .balanced: return "120fps with interpolation"
        case .quality: return "120fps, all enhancements"
        case .retro: return "CRT simulation with scanlines"
        }
    }
}
