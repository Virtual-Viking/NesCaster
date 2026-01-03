//
//  MesenBridge.h
//  NesCaster
//
//  C interface bridge to Mesen NES emulator core
//  This provides a clean C API that Swift can call via the bridging header
//

#ifndef MesenBridge_h
#define MesenBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Constants

#define NES_WIDTH 256
#define NES_HEIGHT 240
#define NES_FRAME_SIZE (NES_WIDTH * NES_HEIGHT * 4)  // RGBA

// MARK: - Types

/// NES controller button flags
typedef enum {
    NESButton_A      = 1 << 0,
    NESButton_B      = 1 << 1,
    NESButton_Select = 1 << 2,
    NESButton_Start  = 1 << 3,
    NESButton_Up     = 1 << 4,
    NESButton_Down   = 1 << 5,
    NESButton_Left   = 1 << 6,
    NESButton_Right  = 1 << 7
} NESButton;

/// Emulator state
typedef enum {
    MesenState_Idle,
    MesenState_Running,
    MesenState_Paused,
    MesenState_Error
} MesenState;

/// ROM load result
typedef enum {
    MesenLoadResult_Success,
    MesenLoadResult_FileNotFound,
    MesenLoadResult_InvalidROM,
    MesenLoadResult_UnsupportedMapper,
    MesenLoadResult_Error
} MesenLoadResult;

/// Audio callback - called when audio samples are ready
/// @param samples Pointer to interleaved stereo 16-bit samples
/// @param sampleCount Number of stereo sample pairs
typedef void (*MesenAudioCallback)(const int16_t* samples, int sampleCount);

/// Frame callback - called when a new frame is ready
/// @param frameBuffer Pointer to RGBA pixel data (256x240)
typedef void (*MesenFrameCallback)(const uint8_t* frameBuffer);

// MARK: - Lifecycle

/// Initialize the Mesen emulator core
/// @return true on success
bool mesen_init(void);

/// Shutdown and cleanup the emulator
void mesen_shutdown(void);

/// Get the current emulator state
MesenState mesen_get_state(void);

// MARK: - ROM Management

/// Load a ROM from file path
/// @param path Path to .nes ROM file
/// @return Load result code
MesenLoadResult mesen_load_rom_file(const char* path);

/// Load a ROM from memory
/// @param data ROM data bytes
/// @param size Size of ROM data
/// @return Load result code
MesenLoadResult mesen_load_rom_data(const uint8_t* data, size_t size);

/// Unload the current ROM
void mesen_unload_rom(void);

/// Check if a ROM is loaded
bool mesen_is_rom_loaded(void);

/// Get the name of the loaded ROM
/// @param buffer Buffer to receive ROM name
/// @param bufferSize Size of buffer
void mesen_get_rom_name(char* buffer, size_t bufferSize);

// MARK: - Emulation Control

/// Start emulation
void mesen_start(void);

/// Pause emulation
void mesen_pause(void);

/// Resume emulation
void mesen_resume(void);

/// Stop emulation
void mesen_stop(void);

/// Reset the console (soft reset)
void mesen_reset(void);

/// Power cycle the console (hard reset)
void mesen_power_cycle(void);

// MARK: - Frame Execution

/// Run a single frame of emulation
/// Call this 60 times per second for proper timing
void mesen_run_frame(void);

/// Get the current frame buffer
/// @return Pointer to RGBA pixel data (256x240x4 bytes)
/// @note Do not free this pointer - it's managed by the emulator
const uint8_t* mesen_get_frame_buffer(void);

/// Set the frame callback
/// @param callback Function to call when frame is ready, or NULL to disable
void mesen_set_frame_callback(MesenFrameCallback callback);

// MARK: - Input

/// Set controller input state
/// @param controller Controller index (0 or 1)
/// @param buttons Bitmask of pressed buttons (NESButton flags)
void mesen_set_input(int controller, uint8_t buttons);

/// Set a specific button state
/// @param controller Controller index (0 or 1)
/// @param button Button to set
/// @param pressed true if pressed, false if released
void mesen_set_button(int controller, NESButton button, bool pressed);

// MARK: - Audio

/// Get audio samples generated during the last frame
/// @param outSamples Pointer to receive sample data
/// @param maxSamples Maximum number of samples to retrieve
/// @return Number of samples written
int mesen_get_audio_samples(int16_t* outSamples, int maxSamples);

/// Set the audio callback
/// @param callback Function to call when audio is ready, or NULL to disable
void mesen_set_audio_callback(MesenAudioCallback callback);

/// Get the audio sample rate
/// @return Sample rate in Hz (typically 44100 or 48000)
int mesen_get_sample_rate(void);

// MARK: - Save States

/// Save current state to slot
/// @param slot Slot number (0-9)
/// @return true on success
bool mesen_save_state(int slot);

/// Load state from slot
/// @param slot Slot number (0-9)
/// @return true on success
bool mesen_load_state(int slot);

/// Save state to memory buffer
/// @param buffer Buffer to receive state data
/// @param bufferSize Size of buffer
/// @return Size of state data, or 0 on error
size_t mesen_save_state_to_buffer(uint8_t* buffer, size_t bufferSize);

/// Load state from memory buffer
/// @param buffer State data
/// @param size Size of state data
/// @return true on success
bool mesen_load_state_from_buffer(const uint8_t* buffer, size_t size);

// MARK: - Quick Save/Load (for run-ahead)

/// Quick save state (fast, no allocation)
void mesen_quick_save(void);

/// Quick load state (fast, no allocation)  
void mesen_quick_load(void);

// MARK: - Configuration

/// Set video overscan (hidden borders)
/// @param top Pixels to hide from top
/// @param bottom Pixels to hide from bottom
/// @param left Pixels to hide from left
/// @param right Pixels to hide from right
void mesen_set_overscan(int top, int bottom, int left, int right);

/// Enable/disable specific audio channels
/// @param square1 Enable square wave 1
/// @param square2 Enable square wave 2
/// @param triangle Enable triangle wave
/// @param noise Enable noise channel
/// @param dmc Enable DMC channel
void mesen_set_audio_channels(bool square1, bool square2, bool triangle, bool noise, bool dmc);

// MARK: - Performance

/// Get current frames per second
double mesen_get_fps(void);

/// Get the frame count since ROM load
uint32_t mesen_get_frame_count(void);

#ifdef __cplusplus
}
#endif

#endif /* MesenBridge_h */

