//
//  NESEmulatorCore.swift
//  NesCaster
//
//  Bridge between Swift and Mesen C++ NES core
//  Handles: ROM loading, frame stepping, input, save states
//

import Foundation
import QuartzCore

// MARK: - NES Button Mapping

struct NESInput: OptionSet, Sendable {
    let rawValue: UInt8
    
    static let a      = NESInput(rawValue: 1 << 0)
    static let b      = NESInput(rawValue: 1 << 1)
    static let select = NESInput(rawValue: 1 << 2)
    static let start  = NESInput(rawValue: 1 << 3)
    static let up     = NESInput(rawValue: 1 << 4)
    static let down   = NESInput(rawValue: 1 << 5)
    static let left   = NESInput(rawValue: 1 << 6)
    static let right  = NESInput(rawValue: 1 << 7)
}

// MARK: - Emulator State

enum EmulatorState: Sendable {
    case idle
    case running
    case paused
    case error(String)
}

// MARK: - NES Emulator Core

@MainActor
class NESEmulatorCore: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var state: EmulatorState = .idle
    @Published private(set) var currentROM: URL?
    @Published private(set) var fps: Double = 0
    @Published private(set) var frameTime: Double = 0
    
    // MARK: - Frame Buffer
    
    /// Raw NES frame buffer (256x240 RGBA)
    private(set) var frameBuffer = [UInt8](repeating: 0, count: 256 * 240 * 4)
    
    /// Frame callback - called when new frame is ready
    var onFrameReady: ((_ buffer: UnsafePointer<UInt8>) -> Void)?
    
    /// Audio callback - called when audio samples are ready
    var onAudioReady: ((_ samples: UnsafePointer<Int16>, _ count: Int) -> Void)?
    
    // MARK: - Input State
    
    private var controller1Input: NESInput = []
    private var controller2Input: NESInput = []
    
    // MARK: - Performance Tracking
    
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fpsUpdateTimer: CFTimeInterval = 0
    
    // MARK: - Constants
    
    static let nesWidth = 256
    static let nesHeight = 240
    static let targetFPS = 60.099 // NTSC NES frame rate
    static let frameInterval = 1.0 / targetFPS
    
    // MARK: - Initialization
    
    init() {
        print("🎮 NESEmulatorCore initialized")
        // TODO: Initialize Mesen core library
        // MesenCore.initialize()
    }
    
    // MARK: - ROM Management
    
    /// Load a ROM file
    func loadROM(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EmulatorError.romNotFound
        }
        
        // Validate ROM format
        let data = try Data(contentsOf: url)
        guard isValidNESROM(data) else {
            throw EmulatorError.invalidROM
        }
        
        currentROM = url
        state = .paused
        
        print("✅ ROM loaded: \(url.lastPathComponent)")
        print("   Size: \(data.count) bytes")
        
        // TODO: Pass ROM data to Mesen core
        // MesenCore.loadROM(data.bytes, data.count)
    }
    
    /// Validate iNES/NES 2.0 header
    private func isValidNESROM(_ data: Data) -> Bool {
        guard data.count >= 16 else { return false }
        
        // Check for "NES\x1A" magic number
        let header = [UInt8](data.prefix(4))
        return header == [0x4E, 0x45, 0x53, 0x1A] // "NES" + EOF
    }
    
    // MARK: - Emulation Control
    
    /// Start emulation
    func start() {
        guard currentROM != nil else {
            state = .error("No ROM loaded")
            return
        }
        
        state = .running
        lastFrameTime = CACurrentMediaTime()
        
        // Start emulation loop on background thread
        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.emulationLoop()
        }
    }
    
    /// Pause emulation
    func pause() {
        state = .paused
    }
    
    /// Resume emulation
    func resume() {
        guard case .paused = state else { return }
        state = .running
    }
    
    /// Stop emulation and unload ROM
    func stop() {
        state = .idle
        currentROM = nil
        frameBuffer = [UInt8](repeating: 0, count: 256 * 240 * 4)
    }
    
    /// Reset the emulator (soft reset)
    func reset() {
        // TODO: MesenCore.reset()
        print("🔄 Emulator reset")
    }
    
    // MARK: - Emulation Loop
    
    private func emulationLoop() async {
        while await checkIsRunning() {
            let frameStart = CACurrentMediaTime()
            
            // Run one frame
            runFrame()
            
            // Frame timing
            let frameEnd = CACurrentMediaTime()
            let elapsed = frameEnd - frameStart
            
            // Sleep to maintain 60 FPS
            let targetSleep = Self.frameInterval - elapsed
            if targetSleep > 0 {
                try? await Task.sleep(nanoseconds: UInt64(targetSleep * 1_000_000_000))
            }
            
            // Update performance metrics
            updatePerformanceMetrics(frameDuration: elapsed)
        }
    }
    
    /// Check if emulator is running (called from async context)
    private func checkIsRunning() async -> Bool {
        if case .running = state {
            return true
        }
        return false
    }
    
    /// Run a single frame of emulation
    private func runFrame() {
        // TODO: Replace with actual Mesen core call
        // MesenCore.runFrame(controller1Input.rawValue, controller2Input.rawValue)
        // MesenCore.getFrameBuffer(&frameBuffer)
        
        // For now, generate test pattern
        generateTestFrame()
        
        // Notify renderer
        frameBuffer.withUnsafeBufferPointer { ptr in
            onFrameReady?(ptr.baseAddress!)
        }
    }
    
    /// Generate test pattern for development
    private func generateTestFrame() {
        frameCount += 1
        
        for y in 0..<Self.nesHeight {
            for x in 0..<Self.nesWidth {
                let index = (y * Self.nesWidth + x) * 4
                
                // Animated gradient pattern
                let r = UInt8((x + frameCount * 2) % 256)
                let g = UInt8((y + frameCount) % 256)
                let b = UInt8((x + y + frameCount * 3) % 256)
                
                frameBuffer[index + 0] = r
                frameBuffer[index + 1] = g
                frameBuffer[index + 2] = b
                frameBuffer[index + 3] = 255
            }
        }
    }
    
    // MARK: - Input Handling
    
    /// Update controller 1 input state
    func setController1Input(_ input: NESInput) {
        controller1Input = input
    }
    
    /// Update controller 2 input state
    func setController2Input(_ input: NESInput) {
        controller2Input = input
    }
    
    /// Press a button on controller 1
    func pressButton(_ button: NESInput, controller: Int = 1) {
        if controller == 1 {
            controller1Input.insert(button)
        } else {
            controller2Input.insert(button)
        }
    }
    
    /// Release a button on controller 1
    func releaseButton(_ button: NESInput, controller: Int = 1) {
        if controller == 1 {
            controller1Input.remove(button)
        } else {
            controller2Input.remove(button)
        }
    }
    
    // MARK: - Save States
    
    /// Save current state
    func saveState(slot: Int) throws -> Data {
        // TODO: MesenCore.saveState()
        print("💾 Save state to slot \(slot)")
        return Data()
    }
    
    /// Load a saved state
    func loadState(slot: Int, data: Data) throws {
        // TODO: MesenCore.loadState(data)
        print("📂 Load state from slot \(slot)")
    }
    
    // MARK: - Performance Metrics
    
    private func updatePerformanceMetrics(frameDuration: Double) {
        frameTime = frameDuration * 1000 // Convert to ms
        
        let now = CACurrentMediaTime()
        if now - fpsUpdateTimer >= 1.0 {
            fps = Double(frameCount) / (now - fpsUpdateTimer)
            frameCount = 0
            fpsUpdateTimer = now
        }
    }
}

// MARK: - Emulator Errors

enum EmulatorError: LocalizedError {
    case romNotFound
    case invalidROM
    case loadFailed(String)
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .romNotFound:
            return "ROM file not found"
        case .invalidROM:
            return "Invalid or corrupted ROM file"
        case .loadFailed(let reason):
            return "Failed to load ROM: \(reason)"
        case .saveFailed(let reason):
            return "Failed to save state: \(reason)"
        }
    }
}
