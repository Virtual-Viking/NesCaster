//
//  MesenBridge.mm
//  NesCaster
//
//  Objective-C++ implementation of Mesen bridge
//  This wraps the C++ Mesen core and exposes it via C interface
//

#import "MesenBridge.h"
#import <Foundation/Foundation.h>
#import <string>
#import <vector>
#import <cstring>

// TODO: Uncomment when Mesen core is compiled for tvOS
// #include "Core/Shared/Emulator.h"
// #include "Core/NES/NesConsole.h"

// MARK: - Internal State

namespace {
    // Emulator state
    MesenState g_state = MesenState_Idle;
    bool g_initialized = false;
    bool g_romLoaded = false;
    
    // Frame buffer (256x240 RGBA)
    uint8_t g_frameBuffer[NES_FRAME_SIZE];
    uint32_t g_frameCount = 0;
    
    // Audio buffer
    std::vector<int16_t> g_audioBuffer;
    
    // Input state
    uint8_t g_controller1 = 0;
    uint8_t g_controller2 = 0;
    
    // Callbacks
    MesenFrameCallback g_frameCallback = nullptr;
    MesenAudioCallback g_audioCallback = nullptr;
    
    // ROM info
    std::string g_romName;
    
    // Quick save buffer for run-ahead
    std::vector<uint8_t> g_quickSaveBuffer;
    
    // TODO: Uncomment when Mesen is compiled
    // std::unique_ptr<Emulator> g_emulator;
}

// MARK: - Test Pattern Generator (Temporary)

static void generateTestPattern() {
    g_frameCount++;
    
    for (int y = 0; y < NES_HEIGHT; y++) {
        for (int x = 0; x < NES_WIDTH; x++) {
            int index = (y * NES_WIDTH + x) * 4;
            
            // Create animated color bars pattern
            int section = x / 32;  // 8 color sections
            uint8_t r = 0, g = 0, b = 0;
            
            switch (section) {
                case 0: r = 255; break;                    // Red
                case 1: r = 255; g = 128; break;           // Orange
                case 2: r = 255; g = 255; break;           // Yellow
                case 3: g = 255; break;                    // Green
                case 4: g = 255; b = 255; break;           // Cyan
                case 5: b = 255; break;                    // Blue
                case 6: r = 128; b = 255; break;           // Purple
                case 7: r = 255; g = 255; b = 255; break;  // White
            }
            
            // Add animation based on frame count
            int wave = (int)(sin((y + g_frameCount * 2) * 0.1) * 30);
            r = (uint8_t)fmax(0, fmin(255, r + wave));
            g = (uint8_t)fmax(0, fmin(255, g + wave));
            b = (uint8_t)fmax(0, fmin(255, b + wave));
            
            // Draw controller input indicator at bottom
            if (y >= NES_HEIGHT - 20) {
                if (g_controller1 != 0) {
                    // Show input activity with brightness
                    r = (uint8_t)fmin(255, r + 100);
                    g = (uint8_t)fmin(255, g + 100);
                    b = (uint8_t)fmin(255, b + 100);
                }
            }
            
            g_frameBuffer[index + 0] = r;
            g_frameBuffer[index + 1] = g;
            g_frameBuffer[index + 2] = b;
            g_frameBuffer[index + 3] = 255;
        }
    }
    
    // Generate test audio (simple sine wave)
    const int samplesPerFrame = 735; // ~44100 / 60
    g_audioBuffer.resize(samplesPerFrame * 2); // Stereo
    
    static float phase = 0;
    float frequency = 440.0f; // A4 note
    float sampleRate = 44100.0f;
    
    for (int i = 0; i < samplesPerFrame; i++) {
        int16_t sample = (int16_t)(sin(phase) * 8000);
        g_audioBuffer[i * 2] = sample;      // Left
        g_audioBuffer[i * 2 + 1] = sample;  // Right
        phase += (2.0f * M_PI * frequency) / sampleRate;
        if (phase > 2.0f * M_PI) phase -= 2.0f * M_PI;
    }
}

// MARK: - Lifecycle

bool mesen_init(void) {
    if (g_initialized) {
        return true;
    }
    
    NSLog(@"🎮 MesenBridge: Initializing emulator core");
    
    // Clear frame buffer
    memset(g_frameBuffer, 0, NES_FRAME_SIZE);
    
    // Initialize audio buffer
    g_audioBuffer.reserve(2048);
    
    // TODO: Initialize actual Mesen core
    // g_emulator = std::make_unique<Emulator>();
    // g_emulator->Initialize();
    
    g_initialized = true;
    g_state = MesenState_Idle;
    
    NSLog(@"✅ MesenBridge: Emulator initialized successfully");
    return true;
}

void mesen_shutdown(void) {
    if (!g_initialized) {
        return;
    }
    
    NSLog(@"🎮 MesenBridge: Shutting down");
    
    mesen_stop();
    
    // TODO: Cleanup Mesen core
    // g_emulator->Stop(true);
    // g_emulator->Release();
    // g_emulator.reset();
    
    g_frameCallback = nullptr;
    g_audioCallback = nullptr;
    g_initialized = false;
    g_romLoaded = false;
    g_state = MesenState_Idle;
}

MesenState mesen_get_state(void) {
    return g_state;
}

// MARK: - ROM Management

MesenLoadResult mesen_load_rom_file(const char* path) {
    if (!g_initialized) {
        mesen_init();
    }
    
    NSLog(@"🎮 MesenBridge: Loading ROM from %s", path);
    
    // Check file exists
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* nsPath = [NSString stringWithUTF8String:path];
    
    if (![fm fileExistsAtPath:nsPath]) {
        NSLog(@"❌ MesenBridge: File not found");
        return MesenLoadResult_FileNotFound;
    }
    
    // Read ROM data
    NSData* romData = [NSData dataWithContentsOfFile:nsPath];
    if (!romData || romData.length < 16) {
        NSLog(@"❌ MesenBridge: Invalid ROM file");
        return MesenLoadResult_InvalidROM;
    }
    
    // Validate iNES header
    const uint8_t* header = (const uint8_t*)romData.bytes;
    if (header[0] != 'N' || header[1] != 'E' || header[2] != 'S' || header[3] != 0x1A) {
        NSLog(@"❌ MesenBridge: Invalid iNES header");
        return MesenLoadResult_InvalidROM;
    }
    
    // TODO: Pass to actual Mesen core
    // if (!g_emulator->LoadRom(path)) {
    //     return MesenLoadResult_Error;
    // }
    
    // Store ROM name
    g_romName = [nsPath.lastPathComponent.stringByDeletingPathExtension UTF8String];
    
    g_romLoaded = true;
    g_state = MesenState_Paused;
    g_frameCount = 0;
    
    NSLog(@"✅ MesenBridge: ROM loaded - %s", g_romName.c_str());
    return MesenLoadResult_Success;
}

MesenLoadResult mesen_load_rom_data(const uint8_t* data, size_t size) {
    if (!g_initialized) {
        mesen_init();
    }
    
    if (!data || size < 16) {
        return MesenLoadResult_InvalidROM;
    }
    
    // Validate iNES header
    if (data[0] != 'N' || data[1] != 'E' || data[2] != 'S' || data[3] != 0x1A) {
        return MesenLoadResult_InvalidROM;
    }
    
    // TODO: Pass to actual Mesen core
    // VirtualFile romFile(data, size);
    // if (!g_emulator->LoadRom(romFile, VirtualFile())) {
    //     return MesenLoadResult_Error;
    // }
    
    g_romName = "ROM";
    g_romLoaded = true;
    g_state = MesenState_Paused;
    g_frameCount = 0;
    
    return MesenLoadResult_Success;
}

void mesen_unload_rom(void) {
    mesen_stop();
    g_romLoaded = false;
    g_romName.clear();
    g_frameCount = 0;
    
    // TODO: Unload from Mesen core
    // g_emulator->Stop(true);
}

bool mesen_is_rom_loaded(void) {
    return g_romLoaded;
}

void mesen_get_rom_name(char* buffer, size_t bufferSize) {
    if (buffer && bufferSize > 0) {
        strncpy(buffer, g_romName.c_str(), bufferSize - 1);
        buffer[bufferSize - 1] = '\0';
    }
}

// MARK: - Emulation Control

void mesen_start(void) {
    if (!g_romLoaded) {
        NSLog(@"⚠️ MesenBridge: Cannot start - no ROM loaded");
        return;
    }
    
    g_state = MesenState_Running;
    
    // TODO: Start Mesen core
    // g_emulator->Resume();
    
    NSLog(@"▶️ MesenBridge: Emulation started");
}

void mesen_pause(void) {
    if (g_state == MesenState_Running) {
        g_state = MesenState_Paused;
        
        // TODO: Pause Mesen core
        // g_emulator->Pause();
        
        NSLog(@"⏸️ MesenBridge: Emulation paused");
    }
}

void mesen_resume(void) {
    if (g_state == MesenState_Paused && g_romLoaded) {
        g_state = MesenState_Running;
        
        // TODO: Resume Mesen core
        // g_emulator->Resume();
        
        NSLog(@"▶️ MesenBridge: Emulation resumed");
    }
}

void mesen_stop(void) {
    g_state = MesenState_Idle;
    g_controller1 = 0;
    g_controller2 = 0;
    
    // TODO: Stop Mesen core
    // g_emulator->Stop(true);
    
    NSLog(@"⏹️ MesenBridge: Emulation stopped");
}

void mesen_reset(void) {
    // TODO: Reset via Mesen core
    // g_emulator->Reset();
    
    g_frameCount = 0;
    NSLog(@"🔄 MesenBridge: Soft reset");
}

void mesen_power_cycle(void) {
    // TODO: Power cycle via Mesen core
    // g_emulator->PowerCycle();
    
    g_frameCount = 0;
    NSLog(@"🔌 MesenBridge: Power cycle");
}

// MARK: - Frame Execution

void mesen_run_frame(void) {
    if (g_state != MesenState_Running) {
        return;
    }
    
    // TODO: Run actual Mesen frame
    // g_emulator->RunFrame();
    // Copy frame buffer from Mesen
    
    // For now, generate test pattern
    generateTestPattern();
    
    // Notify via callback
    if (g_frameCallback) {
        g_frameCallback(g_frameBuffer);
    }
    
    // Audio callback
    if (g_audioCallback && !g_audioBuffer.empty()) {
        g_audioCallback(g_audioBuffer.data(), (int)g_audioBuffer.size() / 2);
    }
}

const uint8_t* mesen_get_frame_buffer(void) {
    return g_frameBuffer;
}

void mesen_set_frame_callback(MesenFrameCallback callback) {
    g_frameCallback = callback;
}

// MARK: - Input

void mesen_set_input(int controller, uint8_t buttons) {
    if (controller == 0) {
        g_controller1 = buttons;
    } else if (controller == 1) {
        g_controller2 = buttons;
    }
    
    // TODO: Pass to Mesen core
    // g_emulator->SetControllerState(controller, buttons);
}

void mesen_set_button(int controller, NESButton button, bool pressed) {
    uint8_t* state = (controller == 0) ? &g_controller1 : &g_controller2;
    
    if (pressed) {
        *state |= (uint8_t)button;
    } else {
        *state &= ~(uint8_t)button;
    }
    
    // TODO: Pass to Mesen core
}

// MARK: - Audio

int mesen_get_audio_samples(int16_t* outSamples, int maxSamples) {
    if (!outSamples || maxSamples <= 0) {
        return 0;
    }
    
    int count = (int)fmin(maxSamples * 2, g_audioBuffer.size());
    memcpy(outSamples, g_audioBuffer.data(), count * sizeof(int16_t));
    
    return count / 2;
}

void mesen_set_audio_callback(MesenAudioCallback callback) {
    g_audioCallback = callback;
}

int mesen_get_sample_rate(void) {
    return 44100;
}

// MARK: - Save States

bool mesen_save_state(int slot) {
    if (!g_romLoaded || slot < 0 || slot > 9) {
        return false;
    }
    
    // TODO: Save via Mesen core
    // g_emulator->GetSaveStateManager()->SaveState(slot);
    
    NSLog(@"💾 MesenBridge: Save state to slot %d", slot);
    return true;
}

bool mesen_load_state(int slot) {
    if (!g_romLoaded || slot < 0 || slot > 9) {
        return false;
    }
    
    // TODO: Load via Mesen core
    // g_emulator->GetSaveStateManager()->LoadState(slot);
    
    NSLog(@"📂 MesenBridge: Load state from slot %d", slot);
    return true;
}

size_t mesen_save_state_to_buffer(uint8_t* buffer, size_t bufferSize) {
    // TODO: Implement with Mesen core
    return 0;
}

bool mesen_load_state_from_buffer(const uint8_t* buffer, size_t size) {
    // TODO: Implement with Mesen core
    return false;
}

// MARK: - Quick Save/Load

void mesen_quick_save(void) {
    // TODO: Implement fast save for run-ahead
    // This should save state without any allocation
}

void mesen_quick_load(void) {
    // TODO: Implement fast load for run-ahead
}

// MARK: - Configuration

void mesen_set_overscan(int top, int bottom, int left, int right) {
    // TODO: Configure Mesen overscan
    // OverscanDimensions overscan = { top, bottom, left, right };
    // g_emulator->GetSettings()->SetOverscan(overscan);
}

void mesen_set_audio_channels(bool square1, bool square2, bool triangle, bool noise, bool dmc) {
    // TODO: Configure Mesen audio channels
}

// MARK: - Performance

double mesen_get_fps(void) {
    // TODO: Get actual FPS from Mesen
    return 60.0;
}

uint32_t mesen_get_frame_count(void) {
    return g_frameCount;
}

