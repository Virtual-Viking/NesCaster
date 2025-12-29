# NesCaster Technical Architecture

## Overview

NesCaster is a high-performance NES emulator targeting modern platforms (Apple TV, iPad, Android) with the following goals:

- **Sub-frame latency** (< original NES hardware ~16.6ms)
- **True 120fps rendering** (not frame doubling)
- **4K crisp output** (integer scaling, pixel-perfect)
- **SDR only** (no HDR for minimal processing overhead)
- **Modern, beautiful UI**

---

## Core Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         NesCaster Architecture                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────┐                                                  │
│  │  Platform UI   │  SwiftUI (tvOS/iOS) / Jetpack Compose (Android) │
│  └───────┬────────┘                                                  │
│          │                                                           │
│          ▼                                                           │
│  ┌────────────────┐                                                  │
│  │  Game Library  │  ROM management, metadata, cover art            │
│  │  & Settings    │                                                  │
│  └───────┬────────┘                                                  │
│          │                                                           │
│          ▼                                                           │
│  ┌────────────────┐     ┌────────────────┐     ┌────────────────┐   │
│  │  Input Manager │────▶│  Mesen Core    │────▶│  Frame Buffer  │   │
│  │  (Controllers) │     │  (C++ NES)     │     │  (256×240)     │   │
│  └────────────────┘     └────────────────┘     └───────┬────────┘   │
│                                │                        │            │
│                                ▼                        ▼            │
│                         ┌────────────────┐     ┌────────────────┐   │
│                         │  Audio Engine  │     │  Metal/Vulkan  │   │
│                         │  (Low Latency) │     │  Renderer      │   │
│                         └────────────────┘     └───────┬────────┘   │
│                                                         │            │
│                                                         ▼            │
│                                                 ┌────────────────┐   │
│                                                 │  Display Output│   │
│                                                 │  4K @ 120fps   │   │
│                                                 └────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Latency Reduction Strategies

### 1. Run-Ahead Emulation

Run-ahead reduces input latency by emulating frames ahead of display, then discarding them.

```
Traditional:
  Input → Frame N → Display → User sees result (~50ms total)

Run-Ahead (1 frame):
  Input → Frame N+1 (predicted) → Display → User sees result (~33ms total)

Implementation:
  1. Save state at frame N
  2. Emulate frame N with current input
  3. Emulate frame N+1 with same input
  4. Load state from step 1
  5. Display frame N+1
```

**Mesen Core Modification Required:** Add save/load state API that operates without allocation.

### 2. Input Polling Optimization

- Poll input at the start of each frame, not during vsync
- Use GameController framework's callback-based input (no polling delay)
- Direct hardware polling on supported controllers

### 3. Display Pipeline

```
Frame Ready → Metal Texture Upload → GPU Upscale → Present
                  │                       │
                  └── Use shared memory ──┘
                       (zero-copy where possible)
```

**Key Metal Settings:**
- `presentsWithTransaction = false`
- `framebufferOnly = true`  
- Disable vsync in low-latency mode
- Use `MTLDrawable.presentAfterMinimumDuration()` for frame pacing

### 4. Audio Latency

- Target: 2 audio frames (~32ms at 60fps)
- Use AudioUnit/AVAudioEngine with minimal buffer size
- Sync audio to video, not vice versa

---

## 120fps Rendering Strategies

The NES runs at 60.0988fps (NTSC). To achieve true 120fps output:

### Option A: Frame Interpolation (Recommended)

Generate intermediate frames using motion estimation or simple blending.

```metal
// Simple temporal interpolation
float4 interpolatedFrame = mix(previousFrame, currentFrame, 0.5);
```

**Advanced:** Motion-compensated frame interpolation (MCFI) using optical flow.

### Option B: Run Core at 120fps

Double the emulation speed, blend each pair of frames.

```
NES Frame 1 → Blend → Display Frame 1
            ↘
NES Frame 2 → Display Frame 2
```

**Pros:** True 120fps motion
**Cons:** 2x CPU load, may affect game timing/physics

### Option C: Scanline Racing (Advanced)

Render the frame as the CRT would - line by line, racing the beam.

```
Scanline 0-60   → Display at T+0
Scanline 60-120 → Display at T+8ms
Scanline 120-180 → Display at T+16ms
...
```

**Pros:** Lowest possible latency
**Cons:** Complex implementation, requires variable refresh rate display

---

## 4K Scaling

### Integer Scaling

NES resolution: 256×240
4K resolution: 3840×2160

Scaling factor: `floor(3840/256) = 15x` horizontal, `floor(2160/240) = 9x` vertical

Use 9× scaling (2304×2160) centered in 4K frame for perfect pixels.

```metal
// Integer scaling in shader
float scale = min(floor(outputSize.x / inputSize.x), 
                  floor(outputSize.y / inputSize.y));
float2 scaledSize = inputSize * scale;
float2 offset = (outputSize - scaledSize) * 0.5;
```

### Aspect Ratio

NES pixel aspect ratio: 8:7 (pixels are wider than tall)
Corrected display: 256 × (8/7) : 240 = 292:240 ≈ 1.22:1

---

## Mesen Core Integration

### Compilation for tvOS/iOS

```bash
# In Shared/mesen/

# Create static library for tvOS
xcodebuild -project MesenCore.xcodeproj \
  -scheme MesenCore \
  -sdk appletvos \
  -configuration Release \
  ARCHS="arm64"

# Create static library for iOS
xcodebuild -project MesenCore.xcodeproj \
  -scheme MesenCore \
  -sdk iphoneos \
  -configuration Release \
  ARCHS="arm64"
```

### C Bridge Interface

```c
// MesenBridge.h

#ifndef MesenBridge_h
#define MesenBridge_h

#include <stdint.h>
#include <stdbool.h>

// Lifecycle
void mesen_init(void);
void mesen_shutdown(void);

// ROM
bool mesen_load_rom(const uint8_t* data, size_t size);
void mesen_unload_rom(void);

// Emulation
void mesen_run_frame(void);
void mesen_reset(bool hard_reset);

// Input (bitmask: A=0, B=1, Select=2, Start=3, Up=4, Down=5, Left=6, Right=7)
void mesen_set_input(int controller, uint8_t buttons);

// Output
const uint8_t* mesen_get_frame_buffer(void);  // Returns 256*240*4 RGBA
const int16_t* mesen_get_audio_buffer(int* sample_count);

// Save States
size_t mesen_save_state(uint8_t* buffer, size_t buffer_size);
bool mesen_load_state(const uint8_t* buffer, size_t size);

// For run-ahead (fast save/load without allocation)
void mesen_quick_save(void);
void mesen_quick_load(void);

#endif
```

---

## Directory Structure

```
NesCaster/
├── Android/              # Android app (Kotlin + Compose)
├── iPad/                 # iOS/iPadOS app
├── Apple TV/             # tvOS app (primary development)
│   └── NesCaster/
│       ├── Core/         # Emulator bridge, input handling
│       ├── Rendering/    # Metal renderer, shaders
│       ├── Views/        # SwiftUI views
│       └── Assets.xcassets
├── Research/             # Documentation, research notes
└── Shared/               # Shared code across platforms
    └── mesen/            # Mesen emulator core (C++)
```

---

## Development Phases

### Phase 1: Foundation (Current)
- [x] Project structure setup
- [x] Basic SwiftUI UI shell
- [x] Metal rendering pipeline (test pattern)
- [x] Controller input handling
- [ ] Compile Mesen core for tvOS

### Phase 2: Core Integration
- [ ] Create C bridge for Mesen
- [ ] Load and run NES ROMs
- [ ] Basic frame output
- [ ] Audio output

### Phase 3: Performance
- [ ] Integer scaling shader
- [ ] 120fps interpolation
- [ ] Run-ahead implementation
- [ ] Audio latency optimization

### Phase 4: Features
- [ ] Save states
- [ ] Game library with cover art
- [ ] Settings persistence
- [ ] Cloud sync

### Phase 5: Polish
- [ ] UI animations and transitions
- [ ] Haptic feedback
- [ ] Accessibility features
- [ ] App Store submission

---

## Resources

- [Mesen Source Code](https://github.com/SourMesen/Mesen2)
- [NES Dev Wiki](https://www.nesdev.org/wiki/)
- [Apple Metal Best Practices](https://developer.apple.com/metal/)
- [Low-Latency Gaming on Apple Platforms](https://developer.apple.com/documentation/metal/gpu_features/understanding_gpu_family_4)

---

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Input Latency | < 16ms | Input → Display delta |
| Frame Time | < 8.3ms | Metal frame render time |
| Audio Latency | < 32ms | Audio buffer size |
| Memory Usage | < 100MB | Instruments profiling |
| CPU Usage | < 30% | Single A-series core |

