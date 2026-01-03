//
//  RunAheadManager.swift
//  NesCaster
//
//  Run-ahead implementation for input latency reduction
//  
//  How it works:
//  1. Save a snapshot of emulator state before processing input
//  2. Run N frames ahead with current input
//  3. Display the N-th frame ahead result
//  4. On next real frame, restore snapshot and run with actual input
//
//  This effectively reduces input latency by N frames (N * 16.67ms at 60fps)
//  at the cost of CPU overhead (running emulation N+1 times per frame)
//

import Foundation
import QuartzCore  // For CACurrentMediaTime

// MARK: - Run-Ahead Configuration

struct RunAheadConfig {
    /// Number of frames to run ahead (0 = disabled, max 4)
    var frames: Int = 0
    
    /// Whether to use secondary instance (more accurate but needs 2x core)
    var useSecondInstance: Bool = false
    
    /// Auto-disable if CPU usage too high
    var autoThrottle: Bool = true
    
    /// CPU threshold to disable (percentage)
    var cpuThreshold: Double = 80.0
}

// MARK: - Emulator State Snapshot

struct EmulatorSnapshot {
    let timestamp: TimeInterval
    let stateData: Data
    
    var totalSize: Int {
        stateData.count
    }
}

// MARK: - Run-Ahead Manager

class RunAheadManager: ObservableObject {
    
    // Configuration
    @Published var config = RunAheadConfig()
    
    // State
    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var currentLatencyReduction: Double = 0 // ms
    @Published private(set) var cpuOverhead: Double = 0 // percentage
    
    // Snapshots
    private var savedSnapshot: EmulatorSnapshot?
    private var frameBuffer: [Data] = []
    
    // Performance tracking
    private var frameTimings: [TimeInterval] = []
    private let maxTimingSamples = 30
    
    // Reference to emulator core
    private weak var emulatorCore: NESEmulatorCore?
    
    // MARK: - Constants
    
    static let maxRunAheadFrames = 4
    static let frameTimeNTSC: Double = 1.0 / 60.0988 // ~16.64ms
    static let frameTimePAL: Double = 1.0 / 50.007   // ~20.00ms
    
    // MARK: - Initialization
    
    init(core: NESEmulatorCore? = nil) {
        self.emulatorCore = core
    }
    
    // MARK: - Configuration
    
    func setRunAheadFrames(_ frames: Int) {
        config.frames = min(max(frames, 0), Self.maxRunAheadFrames)
        isEnabled = config.frames > 0
        currentLatencyReduction = Double(config.frames) * Self.frameTimeNTSC * 1000.0
        
        print("🏃 Run-ahead set to \(config.frames) frames (\(String(format: "%.1f", currentLatencyReduction))ms reduction)")
    }
    
    func setAutoThrottle(enabled: Bool, threshold: Double = 80.0) {
        config.autoThrottle = enabled
        config.cpuThreshold = threshold
    }
    
    // MARK: - Frame Processing
    
    /// Called at the start of each frame before input processing
    func beginFrame() {
        guard isEnabled else { return }
        
        // Save current state using quick save
        mesen_quick_save()
        savedSnapshot = EmulatorSnapshot(
            timestamp: CACurrentMediaTime(),
            stateData: Data()  // Quick save doesn't need data copy
        )
    }
    
    /// Execute run-ahead frames and return the displayed frame
    func executeRunAhead(inputState: UInt8) -> Data? {
        guard isEnabled, config.frames > 0 else { return nil }
        
        let startTime = CACurrentMediaTime()
        
        // Run N frames ahead with current input
        var lastFrame: Data?
        for i in 0..<config.frames {
            // Apply input and step
            mesen_set_input(0, inputState)
            mesen_run_frame()
            
            if i == config.frames - 1 {
                // Capture the final frame
                lastFrame = captureCurrentFrame()
            }
        }
        
        // Track timing
        let frameTime = CACurrentMediaTime() - startTime
        recordFrameTiming(frameTime)
        
        // Auto-throttle check
        if config.autoThrottle {
            checkCPUUsage()
        }
        
        return lastFrame
    }
    
    /// Called at the end of frame to restore state for next real frame
    func endFrame() {
        guard isEnabled, savedSnapshot != nil else { return }
        
        // Restore snapshot using quick load
        mesen_quick_load()
        savedSnapshot = nil
    }
    
    // MARK: - Snapshot Management
    
    private func captureCurrentFrame() -> Data {
        guard let framePtr = mesen_get_frame_buffer() else {
            return Data()
        }
        return Data(bytes: framePtr, count: 256 * 240 * 4)
    }
    
    // MARK: - Performance Monitoring
    
    private func recordFrameTiming(_ time: TimeInterval) {
        frameTimings.append(time)
        if frameTimings.count > maxTimingSamples {
            frameTimings.removeFirst()
        }
        
        // Calculate overhead
        let avgTime = frameTimings.reduce(0, +) / Double(frameTimings.count)
        let baseFrameTime = Self.frameTimeNTSC
        cpuOverhead = (avgTime / baseFrameTime) * 100.0 * Double(config.frames + 1)
    }
    
    private func checkCPUUsage() {
        if cpuOverhead > config.cpuThreshold {
            // Reduce run-ahead frames
            if config.frames > 1 {
                setRunAheadFrames(config.frames - 1)
                print("⚠️ Run-ahead throttled to \(config.frames) frames (CPU: \(String(format: "%.1f", cpuOverhead))%)")
            } else if cpuOverhead > config.cpuThreshold * 1.2 {
                // Disable entirely if still too high
                setRunAheadFrames(0)
                print("⚠️ Run-ahead disabled (CPU: \(String(format: "%.1f", cpuOverhead))%)")
            }
        }
    }
    
    // MARK: - Stats
    
    func getStats() -> RunAheadStats {
        RunAheadStats(
            enabled: isEnabled,
            frames: config.frames,
            latencyReductionMs: currentLatencyReduction,
            cpuOverheadPercent: cpuOverhead,
            snapshotSizeBytes: savedSnapshot?.totalSize ?? 0
        )
    }
}

// MARK: - Run-Ahead Statistics

struct RunAheadStats {
    let enabled: Bool
    let frames: Int
    let latencyReductionMs: Double
    let cpuOverheadPercent: Double
    let snapshotSizeBytes: Int
    
    var description: String {
        if !enabled {
            return "Run-ahead: Disabled"
        }
        return """
        Run-ahead: \(frames) frames
        Latency reduction: \(String(format: "%.1f", latencyReductionMs))ms
        CPU overhead: \(String(format: "%.1f", cpuOverheadPercent))%
        Snapshot size: \(snapshotSizeBytes / 1024)KB
        """
    }
}

// MARK: - Run-Ahead Preset

enum RunAheadPreset: Int, CaseIterable, Identifiable {
    case disabled = 0
    case minimal = 1    // 1 frame (~16ms reduction)
    case standard = 2   // 2 frames (~33ms reduction)
    case aggressive = 3 // 3 frames (~50ms reduction)
    case maximum = 4    // 4 frames (~67ms reduction)
    
    var id: Int { rawValue }
    
    var frames: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .minimal: return "Minimal (1 frame)"
        case .standard: return "Standard (2 frames)"
        case .aggressive: return "Aggressive (3 frames)"
        case .maximum: return "Maximum (4 frames)"
        }
    }
    
    var latencyReduction: String {
        if rawValue == 0 { return "No reduction" }
        let ms = Double(rawValue) * 16.67
        return String(format: "-%.0fms", ms)
    }
    
    var cpuCost: String {
        switch self {
        case .disabled: return "None"
        case .minimal: return "~2x CPU"
        case .standard: return "~3x CPU"
        case .aggressive: return "~4x CPU"
        case .maximum: return "~5x CPU"
        }
    }
}
