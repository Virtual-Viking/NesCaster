//
//  NESEmulatorCore.swift
//  NesCaster
//
//  Bridge between Swift and Mesen C++ NES core
//  Uses MesenBridge.h C interface for emulation
//

import Foundation
import QuartzCore
import UIKit

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
    
    /// Convert to MesenBridge button format
    var mesenButtons: UInt8 {
        return rawValue
    }
}

// MARK: - Emulator State

enum EmulatorState: Sendable, Equatable {
    case idle
    case running
    case paused
    case error(String)
    
    static func == (lhs: EmulatorState, rhs: EmulatorState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.running, .running), (.paused, .paused):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - NES Emulator Core

@MainActor
class NESEmulatorCore: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var state: EmulatorState = .idle
    @Published private(set) var currentROM: URL?
    @Published private(set) var romName: String = ""
    @Published private(set) var fps: Double = 0
    @Published private(set) var frameTime: Double = 0
    
    // MARK: - Audio Engine
    
    private let audioEngine = AudioEngine()
    
    // MARK: - Frame Buffer
    
    /// Frame callback - called when new frame is ready
    var onFrameReady: ((_ buffer: UnsafePointer<UInt8>) -> Void)?
    
    /// Audio callback - called when audio samples are ready
    var onAudioReady: ((_ samples: UnsafePointer<Int16>, _ count: Int) -> Void)?
    
    // MARK: - Private State
    
    private var emulationTask: Task<Void, Never>?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fpsUpdateTimer: CFTimeInterval = 0
    
    // MARK: - Constants
    
    static let nesWidth = Int(NES_WIDTH)
    static let nesHeight = Int(NES_HEIGHT)
    static let targetFPS = 60.099 // NTSC NES frame rate
    static let frameInterval = 1.0 / targetFPS
    
    // MARK: - Initialization
    
    init() {
        print("🎮 NESEmulatorCore: Initializing...")
        
        // Initialize the Mesen bridge
        if mesen_init() {
            print("✅ NESEmulatorCore: Mesen bridge initialized")
        } else {
            print("❌ NESEmulatorCore: Failed to initialize Mesen bridge")
            state = .error("Failed to initialize emulator")
        }
    }
    
    deinit {
        // Note: deinit can't be async, so we just set state
        // The bridge will clean up when app terminates
    }
    
    /// Cleanup resources
    func shutdown() {
        stop()
        mesen_shutdown()
        print("🎮 NESEmulatorCore: Shutdown complete")
    }
    
    // MARK: - ROM Management
    
    /// Load a ROM from file URL
    func loadROM(at url: URL) throws {
        // Stop any current emulation
        stop()
        
        // Load via bridge
        let result = mesen_load_rom_file(url.path)
        
        switch result {
        case MesenLoadResult_Success:
            currentROM = url
            romName = url.deletingPathExtension().lastPathComponent
            state = .paused
            print("✅ ROM loaded: \(romName)")
            
        case MesenLoadResult_FileNotFound:
            throw EmulatorError.romNotFound
            
        case MesenLoadResult_InvalidROM:
            throw EmulatorError.invalidROM
            
        case MesenLoadResult_UnsupportedMapper:
            throw EmulatorError.loadFailed("Unsupported mapper")
            
        default:
            throw EmulatorError.loadFailed("Unknown error")
        }
    }
    
    /// Load a ROM from data
    func loadROM(data: Data, name: String = "ROM") throws {
        stop()
        
        let result = data.withUnsafeBytes { ptr -> MesenLoadResult in
            guard let baseAddress = ptr.baseAddress else {
                return MesenLoadResult_Error
            }
            return mesen_load_rom_data(
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count
            )
        }
        
        switch result {
        case MesenLoadResult_Success:
            currentROM = nil
            romName = name
        state = .paused
            print("✅ ROM loaded from data: \(name)")
            
        case MesenLoadResult_InvalidROM:
            throw EmulatorError.invalidROM
            
        default:
            throw EmulatorError.loadFailed("Failed to load ROM data")
        }
    }
    
    /// Check if a ROM is currently loaded
    var isROMLoaded: Bool {
        return mesen_is_rom_loaded()
    }
    
    // MARK: - Emulation Control
    
    /// Start emulation
    func start() {
        guard state != .running else { return }
        
        // Allow demo mode without ROM
        let hasROM = isROMLoaded
        
        state = .running
        if hasROM {
            mesen_start()
        }
        lastFrameTime = CACurrentMediaTime()
        fpsUpdateTimer = lastFrameTime
        frameCount = 0
        
        // Start audio engine
        do {
            try audioEngine.start()
        } catch {
            print("⚠️ Failed to start audio: \(error)")
        }
        
        // Start emulation loop
        emulationTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.emulationLoop()
        }
        
        print("▶️ Emulation started (ROM: \(hasROM ? "loaded" : "demo mode"))")
    }
    
    /// Pause emulation
    func pause() {
        guard state == .running else { return }
        
        state = .paused
        mesen_pause()
        emulationTask?.cancel()
        emulationTask = nil
        
        print("⏸️ Emulation paused")
    }
    
    /// Resume emulation
    func resume() {
        guard state == .paused, isROMLoaded else { return }
        
        state = .running
        mesen_resume()
        lastFrameTime = CACurrentMediaTime()
        
        emulationTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.emulationLoop()
        }
        
        print("▶️ Emulation resumed")
    }
    
    /// Stop emulation and unload ROM
    func stop() {
        emulationTask?.cancel()
        emulationTask = nil
        
        mesen_stop()
        mesen_unload_rom()
        
        // Stop audio
        audioEngine.stop()
        
        state = .idle
        currentROM = nil
        romName = ""
        fps = 0
        frameTime = 0
        
        print("⏹️ Emulation stopped")
    }
    
    /// Reset the console (soft reset)
    func reset() {
        mesen_reset()
        print("🔄 Console reset")
    }
    
    /// Power cycle (hard reset)
    func powerCycle() {
        mesen_power_cycle()
        print("🔌 Power cycle")
    }
    
    // MARK: - Emulation Loop
    
    private func emulationLoop() async {
        while !Task.isCancelled {
            // Check if still running
            let isRunning = await MainActor.run { self.state == .running }
            guard isRunning else { break }
            
            let frameStart = CACurrentMediaTime()
            
            // Run one frame via bridge
            mesen_run_frame()
            
            // Get frame buffer and notify renderer
            if let frameBuffer = mesen_get_frame_buffer() {
                await MainActor.run {
                    self.onFrameReady?(frameBuffer)
                }
            }
            
            // Get audio samples and send to audio engine
            var audioSampleCount: Int32 = 0
            if let audioBuffer = mesen_get_audio_buffer(&audioSampleCount), audioSampleCount > 0 {
                await MainActor.run {
                    self.audioEngine.addSamples(audioBuffer, count: Int(audioSampleCount))
                }
            }
            
            // Frame timing
            let frameEnd = CACurrentMediaTime()
            let elapsed = frameEnd - frameStart
            
            // Sleep to maintain 60 FPS
            let targetSleep = Self.frameInterval - elapsed
            if targetSleep > 0 {
                try? await Task.sleep(nanoseconds: UInt64(targetSleep * 1_000_000_000))
            }
            
            // Update performance metrics
        await MainActor.run {
                self.updatePerformanceMetrics(frameDuration: elapsed)
            }
        }
    }
    
    // MARK: - Input Handling
    
    /// Update controller 1 input state
    func setController1Input(_ input: NESInput) {
        mesen_set_input(0, input.mesenButtons)
    }
    
    /// Update controller 2 input state
    func setController2Input(_ input: NESInput) {
        mesen_set_input(1, input.mesenButtons)
    }
    
    /// Set a specific button state
    func setButton(_ button: NESInput, pressed: Bool, controller: Int = 0) {
        let mesenButton: NESButton
        
        switch button {
        case .a: mesenButton = NESButton_A
        case .b: mesenButton = NESButton_B
        case .select: mesenButton = NESButton_Select
        case .start: mesenButton = NESButton_Start
        case .up: mesenButton = NESButton_Up
        case .down: mesenButton = NESButton_Down
        case .left: mesenButton = NESButton_Left
        case .right: mesenButton = NESButton_Right
        default: return
        }
        
        mesen_set_button(Int32(controller), mesenButton, pressed)
    }
    
    // MARK: - Save States (Slot-based)
    
    /// Save state to slot (0-9)
    func saveState(slot: Int) -> Bool {
        let success = mesen_save_state(Int32(slot))
        if success {
            print("💾 State saved to slot \(slot)")
        }
        return success
    }
    
    /// Load state from slot (0-9)
    func loadState(slot: Int) -> Bool {
        let success = mesen_load_state(Int32(slot))
        if success {
            print("📂 State loaded from slot \(slot)")
        }
        return success
    }
    
    // MARK: - Save States (Data-based for stack system)
    
    /// Create save state and return as Data
    func createSaveState() -> Data? {
        var size: Int32 = 0
        
        // First call to get size
        guard let dataPtr = mesen_create_save_state(&size), size > 0 else {
            print("❌ Failed to create save state")
            return nil
        }
        
        // Copy to Data
        let data = Data(bytes: dataPtr, count: Int(size))
        
        // Free the bridge-allocated memory
        dataPtr.deallocate()
        
        print("💾 Save state created (\(size) bytes)")
        return data
    }
    
    /// Load save state from Data
    func loadSaveState(_ data: Data) -> Bool {
        let success = data.withUnsafeBytes { ptr -> Bool in
            guard let baseAddress = ptr.baseAddress else { return false }
            return mesen_load_save_state(
                baseAddress.assumingMemoryBound(to: UInt8.self),
                Int32(data.count)
            )
        }
        
        if success {
            print("📂 Save state loaded (\(data.count) bytes)")
        } else {
            print("❌ Failed to load save state")
        }
        return success
    }
    
    /// Capture current frame as PNG Data for thumbnails
    func captureScreenshot() -> Data? {
        guard let frameBuffer = mesen_get_frame_buffer() else {
            return nil
        }
        
        // Create UIImage from RGBA frame buffer
        let width = Self.nesWidth
        let height = Self.nesHeight
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: UnsafeMutableRawPointer(mutating: frameBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        guard let cgImage = context.makeImage() else {
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.7)
    }
    
    // MARK: - Quick Save/Load (for run-ahead)
    
    /// Quick save for run-ahead (fast, no allocation)
    func quickSave() {
        mesen_quick_save()
    }
    
    /// Quick load for run-ahead (fast, no allocation)
    func quickLoad() {
        mesen_quick_load()
    }
    
    // MARK: - Performance Metrics
    
    private func updatePerformanceMetrics(frameDuration: Double) {
        frameTime = frameDuration * 1000 // Convert to ms
        frameCount += 1
        
        let now = CACurrentMediaTime()
        let elapsed = now - fpsUpdateTimer
        
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            fpsUpdateTimer = now
        }
    }
    
    /// Get current frame count from bridge
    var totalFrameCount: UInt32 {
        return mesen_get_frame_count()
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
