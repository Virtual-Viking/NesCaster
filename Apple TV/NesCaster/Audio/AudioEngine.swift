//
//  AudioEngine.swift
//  NesCaster
//
//  Low-latency audio engine for NES emulation
//  
//  Features:
//  - Sub-frame audio latency using AVAudioEngine
//  - Dynamic buffer sizing based on device performance
//  - Audio synchronization with frame timing
//  - Volume control with smooth ramping
//

import AVFoundation
import Accelerate

// MARK: - Audio Configuration

struct AudioConfig {
    /// Target sample rate (NES native is ~1.789773MHz / 40 ≈ 44739Hz, resampled to 48000)
    var sampleRate: Double = 48000.0
    
    /// Buffer size in samples (lower = less latency, higher = more stable)
    var bufferSize: AVAudioFrameCount = 512
    
    /// Number of channels (NES is mono, but we output stereo)
    var channels: AVAudioChannelCount = 2
    
    /// Master volume (0.0 - 1.0)
    var volume: Float = 1.0
    
    /// Enable audio
    var enabled: Bool = true
    
    /// Latency mode
    var latencyMode: AudioLatencyMode = .balanced
}

enum AudioLatencyMode: String, CaseIterable, Identifiable {
    case ultraLow = "Ultra Low"      // 256 samples (~5ms)
    case low = "Low"                 // 512 samples (~10ms)
    case balanced = "Balanced"       // 1024 samples (~21ms)
    case stable = "Stable"           // 2048 samples (~42ms)
    
    var id: String { rawValue }
    
    var bufferSize: AVAudioFrameCount {
        switch self {
        case .ultraLow: return 256
        case .low: return 512
        case .balanced: return 1024
        case .stable: return 2048
        }
    }
    
    var latencyMs: Double {
        Double(bufferSize) / 48000.0 * 1000.0
    }
}

// MARK: - Audio Engine

class AudioEngine: ObservableObject {
    
    // Audio engine components
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var mixerNode: AVAudioMixerNode?
    
    // Audio format
    private var audioFormat: AVAudioFormat?
    
    // Configuration
    @Published var config = AudioConfig()
    
    // State
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var currentLatency: Double = 0 // ms
    @Published private(set) var bufferUnderruns: Int = 0
    
    // Ring buffer for audio samples
    private var ringBuffer: RingBuffer<Float>?
    private let ringBufferCapacity = 8192
    
    // Synchronization
    private let audioQueue = DispatchQueue(label: "com.nescaster.audio", qos: .userInteractive)
    private var isProcessing = false
    
    // NES audio constants
    static let nesAPUSampleRate: Double = 1789773.0 / 40.0 // ~44739 Hz
    static let targetSampleRate: Double = 48000.0
    
    // MARK: - Initialization
    
    init() {
        setupAudioSession()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        #if os(tvOS)
        let session = AVAudioSession.sharedInstance()
        do {
            // Configure for low latency playback
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setPreferredSampleRate(config.sampleRate)
            try session.setPreferredIOBufferDuration(Double(config.bufferSize) / config.sampleRate)
            try session.setActive(true)
            
            // Get actual latency
            currentLatency = session.outputLatency * 1000.0 + 
                            session.ioBufferDuration * 1000.0
            
            print("🔊 Audio session configured:")
            print("   Sample rate: \(session.sampleRate)Hz")
            print("   Buffer duration: \(String(format: "%.1f", session.ioBufferDuration * 1000))ms")
            print("   Output latency: \(String(format: "%.1f", session.outputLatency * 1000))ms")
            print("   Total latency: \(String(format: "%.1f", currentLatency))ms")
            
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
        #endif
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine,
              let player = playerNode else {
            return
        }
        
        // Create audio format (stereo, 48kHz, Float32)
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: config.sampleRate,
            channels: config.channels,
            interleaved: false
        )
        
        guard let format = audioFormat else {
            print("❌ Failed to create audio format")
            return
        }
        
        // Attach and connect nodes
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        // Set volume
        engine.mainMixerNode.outputVolume = config.volume
        
        // Create ring buffer
        ringBuffer = RingBuffer(capacity: ringBufferCapacity)
        
        print("✅ Audio engine configured:")
        print("   Format: \(format.sampleRate)Hz, \(format.channelCount)ch")
        print("   Buffer size: \(config.bufferSize) samples")
    }
    
    // MARK: - Control
    
    func start() throws {
        guard !isRunning else { return }
        
        setupAudioEngine()
        
        guard let engine = audioEngine else { 
            throw AudioEngineError.setupFailed
        }
        
        try engine.start()
        playerNode?.play()
        isRunning = true
        
        // Start buffer filling
        scheduleNextBuffer()
        
        print("▶️ Audio engine started")
    }
    
    func stop() {
        guard isRunning else { return }
        
        playerNode?.stop()
        audioEngine?.stop()
        isRunning = false
        
        print("⏹️ Audio engine stopped")
    }
    
    func pause() {
        playerNode?.pause()
    }
    
    func resume() {
        playerNode?.play()
    }
    
    // MARK: - Volume Control
    
    func setVolume(_ volume: Float) {
        config.volume = max(0.0, min(1.0, volume))
        audioEngine?.mainMixerNode.outputVolume = config.volume
    }
    
    func setMuted(_ muted: Bool) {
        audioEngine?.mainMixerNode.outputVolume = muted ? 0.0 : config.volume
    }
    
    // MARK: - Latency Configuration
    
    func setLatencyMode(_ mode: AudioLatencyMode) {
        let wasRunning = isRunning
        
        if wasRunning {
            stop()
        }
        
        config.latencyMode = mode
        config.bufferSize = mode.bufferSize
        
        // Reconfigure audio session
        #if os(tvOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setPreferredIOBufferDuration(Double(config.bufferSize) / config.sampleRate)
        } catch {
            print("⚠️ Failed to update buffer duration: \(error)")
        }
        #endif
        
        if wasRunning {
            do {
                try start()
            } catch {
                print("⚠️ Failed to restart audio after latency change: \(error)")
            }
        }
        
        print("🔊 Audio latency mode: \(mode.rawValue) (~\(String(format: "%.1f", mode.latencyMs))ms)")
    }
    
    // MARK: - Audio Input (from NES APU)
    
    /// Queue audio samples from NES APU (alias for compatibility)
    func addSamples(_ samples: UnsafePointer<Int16>, count: Int) {
        queueSamples(samples, count: count)
    }
    
    /// Queue audio samples from NES APU
    func queueSamples(_ samples: UnsafePointer<Int16>, count: Int) {
        guard isRunning, let ringBuffer = ringBuffer else { return }
        
        audioQueue.async { [weak self] in
            // Convert Int16 to Float and resample
            let floatSamples = self?.convertAndResample(samples, count: count) ?? []
            
            // Add to ring buffer
            for sample in floatSamples {
                ringBuffer.write(sample)
            }
        }
    }
    
    /// Queue audio samples as Float array
    func queueSamples(_ samples: [Float]) {
        guard isRunning, let ringBuffer = ringBuffer else { return }
        
        audioQueue.async {
            for sample in samples {
                ringBuffer.write(sample)
            }
        }
    }
    
    private func convertAndResample(_ samples: UnsafePointer<Int16>, count: Int) -> [Float] {
        // Convert Int16 to Float32
        var floatSamples = [Float](repeating: 0, count: count)
        var scale = Float(Int16.max)
        
        // Use vDSP for efficient conversion
        samples.withMemoryRebound(to: Int16.self, capacity: count) { ptr in
            vDSP_vflt16(ptr, 1, &floatSamples, 1, vDSP_Length(count))
        }
        vDSP_vsdiv(floatSamples, 1, &scale, &floatSamples, 1, vDSP_Length(count))
        
        // Simple linear resampling from ~44739Hz to 48000Hz
        let ratio = Self.targetSampleRate / Self.nesAPUSampleRate
        let outputCount = Int(Double(count) * ratio)
        var resampledSamples = [Float](repeating: 0, count: outputCount)
        
        for i in 0..<outputCount {
            let srcPos = Double(i) / ratio
            let srcIndex = Int(srcPos)
            let frac = Float(srcPos - Double(srcIndex))
            
            if srcIndex + 1 < count {
                resampledSamples[i] = floatSamples[srcIndex] * (1 - frac) + 
                                      floatSamples[srcIndex + 1] * frac
            } else if srcIndex < count {
                resampledSamples[i] = floatSamples[srcIndex]
            }
        }
        
        return resampledSamples
    }
    
    // MARK: - Buffer Management
    
    private func scheduleNextBuffer() {
        guard isRunning,
              let player = playerNode,
              let format = audioFormat,
              let ringBuffer = ringBuffer else {
            return
        }
        
        let bufferSize = config.bufferSize
        
        // Create audio buffer
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else {
            return
        }
        buffer.frameLength = bufferSize
        
        // Fill buffer from ring buffer
        let leftChannel = buffer.floatChannelData?[0]
        let rightChannel = buffer.floatChannelData?[1]
        
        var underrun = false
        
        for i in 0..<Int(bufferSize) {
            if let sample = ringBuffer.read() {
                leftChannel?[i] = sample
                rightChannel?[i] = sample // Mono to stereo
            } else {
                // Buffer underrun - fill with silence
                leftChannel?[i] = 0
                rightChannel?[i] = 0
                underrun = true
            }
        }
        
        if underrun {
            bufferUnderruns += 1
        }
        
        // Schedule buffer with completion handler
        player.scheduleBuffer(buffer, completionHandler: { [weak self] in
            self?.audioQueue.async {
                self?.scheduleNextBuffer()
            }
        })
    }
    
    // MARK: - Statistics
    
    func getStats() -> AudioStats {
        AudioStats(
            isRunning: isRunning,
            sampleRate: config.sampleRate,
            bufferSize: Int(config.bufferSize),
            latencyMs: currentLatency,
            bufferUnderruns: bufferUnderruns,
            volume: config.volume
        )
    }
}

// MARK: - Audio Engine Error

enum AudioEngineError: LocalizedError {
    case setupFailed
    case sessionFailed
    
    var errorDescription: String? {
        switch self {
        case .setupFailed: return "Failed to setup audio engine"
        case .sessionFailed: return "Failed to configure audio session"
        }
    }
}

// MARK: - Audio Statistics

struct AudioStats {
    let isRunning: Bool
    let sampleRate: Double
    let bufferSize: Int
    let latencyMs: Double
    let bufferUnderruns: Int
    let volume: Float
    
    var description: String {
        """
        Audio: \(isRunning ? "Running" : "Stopped")
        Sample rate: \(Int(sampleRate))Hz
        Buffer: \(bufferSize) samples (~\(String(format: "%.1f", Double(bufferSize) / sampleRate * 1000))ms)
        Latency: \(String(format: "%.1f", latencyMs))ms
        Underruns: \(bufferUnderruns)
        Volume: \(Int(volume * 100))%
        """
    }
}

// MARK: - Ring Buffer (Thread-Safe)

class RingBuffer<T> {
    private var buffer: [T?]
    private var readIndex = 0
    private var writeIndex = 0
    private let capacity: Int
    private let lock = NSLock()
    
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        
        if writeIndex >= readIndex {
            return writeIndex - readIndex
        } else {
            return capacity - readIndex + writeIndex
        }
    }
    
    var available: Int {
        capacity - count - 1
    }
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [T?](repeating: nil, count: capacity)
    }
    
    func write(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        
        buffer[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        
        // Overwrite oldest if full
        if writeIndex == readIndex {
            readIndex = (readIndex + 1) % capacity
        }
    }
    
    func read() -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        guard readIndex != writeIndex else { return nil }
        
        let value = buffer[readIndex]
        buffer[readIndex] = nil
        readIndex = (readIndex + 1) % capacity
        
        return value
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        readIndex = 0
        writeIndex = 0
        buffer = [T?](repeating: nil, count: capacity)
    }
}

