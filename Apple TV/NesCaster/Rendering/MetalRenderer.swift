//
//  MetalRenderer.swift
//  NesCaster
//
//  High-performance Metal renderer for NES emulation
//  Features:
//  - 4K upscaling with integer scaling
//  - 120fps frame interpolation
//  - Sub-frame latency rendering
//  - SDR optimized pipeline
//

import Metal
import MetalKit
import simd

// MARK: - Renderer Configuration

struct RendererConfig {
    var targetResolution: SIMD2<Int32> = [3840, 2160]  // 4K
    var targetFrameRate: Int = 120
    var useIntegerScaling: Bool = true
    var enableFrameInterpolation: Bool = true
    var overscanTop: Int = 8
    var overscanBottom: Int = 8
    var overscanLeft: Int = 0
    var overscanRight: Int = 0
}

// MARK: - Metal Renderer

class MetalRenderer: NSObject, MTKViewDelegate {
    
    // Metal objects
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var computePipeline: MTLComputePipelineState?
    
    // Textures
    private var nesFrameTexture: MTLTexture!          // Raw NES output (256x240)
    private var scaledTexture: MTLTexture?            // Upscaled texture
    private var previousFrameTexture: MTLTexture?    // For interpolation
    
    // Buffers
    private var vertexBuffer: MTLBuffer!
    private var uniformBuffer: MTLBuffer!
    
    // Configuration
    var config = RendererConfig()
    
    // Frame timing
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    
    // NES frame buffer (256x240 RGBA)
    private var nesFrameBuffer = [UInt8](repeating: 0, count: 256 * 240 * 4)
    
    // MARK: - NES Display Constants
    
    static let nesWidth = 256
    static let nesHeight = 240
    static let nesAspectRatio: Float = 256.0 / 240.0 * (8.0 / 7.0) // PAR corrected
    
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
    }
    
    // MARK: - Setup
    
    private func setupMetal(mtkView: MTKView) {
        // Configure view for low latency
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = true
        mtkView.preferredFramesPerSecond = config.targetFrameRate
        mtkView.presentsWithTransaction = false
        
        // Create shader library
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load Metal shader library")
        }
        
        // Create render pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create render pipeline: \(error)")
        }
        
        // Create compute pipeline for upscaling
        if let computeFunction = library.makeFunction(name: "upscaleKernel") {
            do {
                computePipeline = try device.makeComputePipelineState(function: computeFunction)
            } catch {
                print("⚠️ Compute pipeline creation failed: \(error)")
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
        
        // Scaled texture (4K)
        let scaledDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(config.targetResolution.x),
            height: Int(config.targetResolution.y),
            mipmapped: false
        )
        scaledDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        scaledDescriptor.storageMode = .private
        
        scaledTexture = device.makeTexture(descriptor: scaledDescriptor)
        scaledTexture?.label = "Scaled Output"
    }
    
    private func createBuffers() {
        // Full-screen quad vertices
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
        
        // Uniform buffer for shader parameters
        var uniforms = ShaderUniforms(
            inputSize: SIMD2<Float>(Float(Self.nesWidth), Float(Self.nesHeight)),
            outputSize: SIMD2<Float>(Float(config.targetResolution.x), Float(config.targetResolution.y)),
            time: 0,
            interpolationFactor: 0
        )
        
        uniformBuffer = device.makeBuffer(
            bytes: &uniforms,
            length: MemoryLayout<ShaderUniforms>.stride,
            options: .storageModeShared
        )
        uniformBuffer.label = "Uniforms"
    }
    
    // MARK: - Frame Update
    
    /// Call this when NES core produces a new frame
    func updateFrame(pixelData: UnsafePointer<UInt8>) {
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
    
    /// For testing - fill with gradient
    func updateWithTestPattern(frame: Int) {
        for y in 0..<Self.nesHeight {
            for x in 0..<Self.nesWidth {
                let index = (y * Self.nesWidth + x) * 4
                nesFrameBuffer[index + 0] = UInt8((x + frame) % 256)     // R
                nesFrameBuffer[index + 1] = UInt8((y + frame/2) % 256)   // G
                nesFrameBuffer[index + 2] = UInt8((x + y + frame) % 256) // B
                nesFrameBuffer[index + 3] = 255                           // A
            }
        }
        
        nesFrameBuffer.withUnsafeBufferPointer { ptr in
            updateFrame(pixelData: ptr.baseAddress!)
        }
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        config.targetResolution = SIMD2<Int32>(Int32(size.width), Int32(size.height))
        createTextures() // Recreate textures for new size
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        // Update uniforms
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        lastFrameTime = currentTime
        
        var uniforms = ShaderUniforms(
            inputSize: SIMD2<Float>(Float(Self.nesWidth), Float(Self.nesHeight)),
            outputSize: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            time: Float(currentTime),
            interpolationFactor: Float(deltaTime * 60.0).truncatingRemainder(dividingBy: 1.0)
        )
        uniformBuffer.contents().copyMemory(from: &uniforms, byteCount: MemoryLayout<ShaderUniforms>.stride)
        
        // Test pattern for development
        frameCount += 1
        updateWithTestPattern(frame: frameCount)
        
        // Render
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(nesFrameTexture, index: 0)
        
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Shader Uniforms

struct ShaderUniforms {
    var inputSize: SIMD2<Float>
    var outputSize: SIMD2<Float>
    var time: Float
    var interpolationFactor: Float
}

