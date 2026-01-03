//
//  AudioEngine.swift
//  NesCaster
//
//  Low-latency audio output for NES emulation using AVAudioEngine
//  Target: < 20ms audio latency
//

import AVFoundation
import Accelerate

// MARK: - Audio Configuration

struct AudioConfig {
    /// NES APU sample rate (matches original hardware)
    static let nesSampleRate: Double = 44100
    
    /// Output sample rate (matches device)
    static let outputSampleRate: Double = 48000
    
    /// Buffer size (smaller = lower latency, but more CPU)
    static let bufferSize: AVAudioFrameCount = 512
    
    /// Number of channels (NES is mono, we duplicate to stereo)
    static let channels: AVAudioChannelCount = 2
    
    /// Ring buffer size (must be power of 2)
    static let ringBufferSize: Int = 8192
}

// MARK: - Audio Engine

@MainActor
class AudioEngine: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var isRunning = false
    @Published private(set) var latencyMs: Double = 0
    @Published private(set) var bufferUnderruns: Int = 0
    
    // MARK: - Audio Components
    
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var mixerNode: AVAudioMixerNode?
    
    // MARK: - Ring Buffer (Lock-free)
    
    private var ringBuffer: [Float]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private let bufferMask: Int
    
    // MARK: - Sample Rate Conversion
    
    private var resampleRatio: Double = 1.0
    private var resampleBuffer: [Float] = []
    private var fractionalIndex: Double = 0
    
    // MARK: - Configuration
    
    var volume: Float = 1.0 {
        didSet {
            mixerNode?.outputVolume = volume
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize ring buffer (must be power of 2)
        let size = AudioConfig.ringBufferSize
        self.ringBuffer = [Float](repeating: 0, count: size)
        self.bufferMask = size - 1
        
        // Calculate resample ratio
        resampleRatio = AudioConfig.outputSampleRate / AudioConfig.nesSampleRate
        
        print("🔊 AudioEngine initialized")
        print("   NES sample rate: \(AudioConfig.nesSampleRate) Hz")
        print("   Output sample rate: \(AudioConfig.outputSampleRate) Hz")
        print("   Resample ratio: \(resampleRatio)")
    }
    
    // MARK: - Engine Control
    
    func start() throws {
        guard !isRunning else { return }
        
        // Configure audio session
        try configureAudioSession()
        
        // Create engine
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        // Get output format
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate
        
        print("🔊 Output format: \(sampleRate) Hz, \(outputFormat.channelCount) channels")
        
        // Create source node that pulls from ring buffer
        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            return self.renderAudio(
                frameCount: frameCount,
                audioBufferList: audioBufferList
            )
        }
        self.sourceNode = sourceNode
        
        // Create mixer for volume control
        let mixer = AVAudioMixerNode()
        self.mixerNode = mixer
        mixer.outputVolume = volume
        
        // Connect nodes
        engine.attach(sourceNode)
        engine.attach(mixer)
        
        let sourceFormat = AVAudioFormat(
            standardFormatWithSampleRate: AudioConfig.outputSampleRate,
            channels: AudioConfig.channels
        )!
        
        engine.connect(sourceNode, to: mixer, format: sourceFormat)
        engine.connect(mixer, to: engine.mainMixerNode, format: sourceFormat)
        
        // Start engine
        try engine.start()
        isRunning = true
        
        // Calculate latency
        let bufferDuration = Double(AudioConfig.bufferSize) / AudioConfig.outputSampleRate
        latencyMs = bufferDuration * 1000
        
        print("✅ AudioEngine started (latency: \(String(format: "%.1f", latencyMs)) ms)")
    }
    
    func stop() {
        audioEngine?.stop()
        audioEngine = nil
        sourceNode = nil
        mixerNode = nil
        isRunning = false
        
        // Clear buffer
        writeIndex = 0
        readIndex = 0
        ringBuffer = [Float](repeating: 0, count: AudioConfig.ringBufferSize)
        
        print("🔇 AudioEngine stopped")
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setPreferredSampleRate(AudioConfig.outputSampleRate)
        try session.setPreferredIOBufferDuration(Double(AudioConfig.bufferSize) / AudioConfig.outputSampleRate)
        try session.setActive(true)
        
        print("🔊 Audio session configured")
    }
    
    // MARK: - Sample Input (from NES APU)
    
    /// Add audio samples from NES APU (16-bit signed, mono)
    func addSamples(_ samples: UnsafePointer<Int16>, count: Int) {
        // Convert Int16 to Float and resample
        for i in 0..<count {
            // Convert to float (-1.0 to 1.0)
            let sample = Float(samples[i]) / 32768.0
            
            // Write to ring buffer
            let index = writeIndex & bufferMask
            ringBuffer[index] = sample
            writeIndex += 1
        }
    }
    
    /// Add audio samples (float, mono)
    func addSamples(_ samples: [Float]) {
        for sample in samples {
            let index = writeIndex & bufferMask
            ringBuffer[index] = sample
            writeIndex += 1
        }
    }
    
    // MARK: - Audio Rendering (Called on audio thread)
    
    private func renderAudio(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        
        // Check available samples
        let available = (writeIndex - readIndex) & bufferMask
        let needed = Int(frameCount)
        
        if available < needed {
            // Buffer underrun - output silence
            bufferUnderruns += 1
            for buffer in ablPointer {
                memset(buffer.mData, 0, Int(buffer.mDataByteSize))
            }
            return noErr
        }
        
        // Render audio
        for buffer in ablPointer {
            guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            
            for frame in 0..<Int(frameCount) {
                // Read from ring buffer with linear interpolation
                let index = readIndex & bufferMask
                let sample = ringBuffer[index]
                
                // Write to both channels (mono to stereo)
                let channelCount = Int(buffer.mNumberChannels)
                for channel in 0..<channelCount {
                    data[frame * channelCount + channel] = sample * volume
                }
                
                readIndex += 1
            }
        }
        
        return noErr
    }
    
    // MARK: - Utilities
    
    /// Get current buffer fill level (0.0 - 1.0)
    var bufferFillLevel: Float {
        let available = (writeIndex - readIndex) & bufferMask
        return Float(available) / Float(AudioConfig.ringBufferSize)
    }
    
    /// Clear the audio buffer
    func clearBuffer() {
        writeIndex = 0
        readIndex = 0
    }
}

// MARK: - Test Tone Generator (for debugging)

extension AudioEngine {
    
    /// Generate test tone to verify audio output
    func playTestTone(frequency: Double = 440, duration: Double = 0.5) {
        let sampleCount = Int(AudioConfig.nesSampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) / AudioConfig.nesSampleRate
            let sample = Float(sin(2.0 * .pi * frequency * time) * 0.3)
            samples[i] = sample
        }
        
        addSamples(samples)
        print("🎵 Playing test tone: \(frequency) Hz for \(duration)s")
    }
}

