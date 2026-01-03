# NesCaster Technical Architecture

## Overview

NesCaster is a high-performance NES emulator targeting modern platforms (Apple TV, iPad, Android) with the following goals:

- **Sub-frame latency** (< original NES hardware ~16.6ms)
- **True 120fps rendering** (not frame doubling)
- **4K crisp output** (integer scaling, pixel-perfect)
- **Multi-profile support** (Netflix-style user switching)
- **Smart save states** (history-based, never lose progress)
- **Modern, beautiful UI**

---

## Core Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           NesCaster Architecture                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      Profile Selection Layer                         │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │    │
│  │  │ Profile 1│  │ Profile 2│  │ Profile 3│  │ Profile 4│            │    │
│  │  │ (Active) │  │          │  │          │  │   Add    │            │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘            │    │
│  └────────────────────────────────┬────────────────────────────────────┘    │
│                                   │                                          │
│                                   ▼                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         Platform UI Layer                            │    │
│  │  SwiftUI (tvOS/iOS) / Jetpack Compose (Android)                     │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │    │
│  │  │ Library  │  │ Emulator │  │ Settings │  │ Transfer │            │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘            │    │
│  └────────────────────────────────┬────────────────────────────────────┘    │
│                                   │                                          │
│         ┌─────────────────────────┼─────────────────────────┐               │
│         │                         │                         │               │
│         ▼                         ▼                         ▼               │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐         │
│  │ Profile Manager │    │   Input Manager │    │   Web Server    │         │
│  │  - Data Model   │    │  - Controllers  │    │ - File Transfer │         │
│  │  - Persistence  │    │  - Per-profile  │    │ - QR Code       │         │
│  │  - Pictures     │    │    mapping      │    │   (TV only)     │         │
│  └────────┬────────┘    └────────┬────────┘    └─────────────────┘         │
│           │                      │                                          │
│           │                      ▼                                          │
│           │             ┌─────────────────┐                                 │
│           │             │   Mesen Core    │                                 │
│           │             │   (C++ NES)     │                                 │
│           │             └────────┬────────┘                                 │
│           │                      │                                          │
│           │         ┌────────────┼────────────┐                            │
│           │         │            │            │                            │
│           │         ▼            ▼            ▼                            │
│           │  ┌───────────┐ ┌───────────┐ ┌───────────┐                    │
│           │  │  Frame    │ │  Audio    │ │  Save     │                    │
│           │  │  Buffer   │ │  Engine   │ │  State    │                    │
│           │  │ (256×240) │ │           │ │  Manager  │◀───────────────────│
│           │  └─────┬─────┘ └───────────┘ └───────────┘                    │
│           │        │                                                       │
│           │        ▼                                                       │
│           │  ┌─────────────────┐                                          │
│           │  │  Metal/Vulkan   │                                          │
│           │  │  Renderer       │                                          │
│           │  │  4K @ 120fps    │                                          │
│           │  └─────────────────┘                                          │
│           │                                                                │
└───────────┴────────────────────────────────────────────────────────────────┘
```

---

## Profile System Architecture

### Data Model

```swift
struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var pictureID: String
    var createdAt: Date
    var lastUsedAt: Date
}

// Each profile has isolated directories:
// ~/Profiles/{id}/ROMs/
// ~/Profiles/{id}/Saves/
// ~/Profiles/{id}/settings.json
// ~/Profiles/{id}/controller.json
```

### Profile Picture System

```
Shared/ProfilePictures/
├── Animated/           # Lottie JSON animations
│   ├── mario.json
│   └── link.json
├── Static/             # PNG/SVG images
│   └── controller.png
└── manifest.json       # Picture metadata
```

Pictures are discovered at runtime from the manifest file.

### Per-Profile Controller Mapping

```swift
struct ControllerMapping: Codable {
    var profileID: UUID
    var controllerID: String
    
    // NES button → Physical button
    var buttonA: ControllerButton
    var buttonB: ControllerButton
    var buttonStart: ControllerButton
    var buttonSelect: ControllerButton
    var dpadUp: ControllerButton
    var dpadDown: ControllerButton
    var dpadLeft: ControllerButton
    var dpadRight: ControllerButton
    
    // Quick actions
    var quickSave: ControllerButton  // Default: L1
    var quickLoad: ControllerButton  // Default: R1
}
```

---

## Save State Architecture

### The Problem

Traditional save states use fixed slots. If you accidentally save over your progress, it's lost.

### The Solution: Stack-Based History

```
Save Stack (configurable: 5/10/15 slots)
┌─────────────────────────────────────┐
│ [0] Latest - Level 3-2 @ 2:34 PM    │ ← Load picks this by default
│ [1] Level 3-1 @ 2:31 PM             │
│ [2] Level 2-4 @ 2:28 PM             │
│ [3] Level 2-3 @ 2:25 PM             │
│ [4] Level 2-2 @ 2:20 PM (Oldest)    │ ← Deleted on next save
└─────────────────────────────────────┘
```

### Save State Data Model

```swift
struct SaveStateEntry: Identifiable, Codable {
    let id: UUID
    let gameID: String          // ROM hash
    let profileID: UUID
    let timestamp: Date
    let screenshotData: Data    // JPEG thumbnail
    let stateData: Data         // Emulator state
    let metadata: SaveMetadata
}

struct SaveMetadata: Codable {
    var gameName: String
    var playTime: TimeInterval
    var levelHint: String?      // Auto-detected if possible
    var isAutoSave: Bool
}
```

### Auto-Save System

Auto-saves trigger on:
1. **Level completion** (detected via RAM watch or screen analysis)
2. **Time interval** (every N minutes, configurable)
3. **Game pause** (when user opens menu)

Auto-saves are stored separately from manual saves.

### User Flow

**Saving:**
```
Press L1 → Toast "Saved!" → Game continues (instant)
```

**Loading:**
```
Press R1 → Dropdown with screenshots → Select with D-pad → Press A to load
```

---

## Content Transfer System

### Apple TV / Android TV: Web Server

When "Add Content" is selected:

1. Start HTTP server on port 8080
2. Display QR code and URL
3. User opens URL on phone/computer
4. Web UI allows drag-and-drop uploads
5. Files saved to active profile's directory

```
┌──────────────────────────────────────────┐
│  NesCaster Content Transfer              │
│                                          │
│        ┌──────────────┐                 │
│        │   QR CODE    │                 │
│        └──────────────┘                 │
│                                          │
│     http://192.168.1.42:8080            │
│                                          │
│     Same network • Auto-closes          │
└──────────────────────────────────────────┘
```

### iPad / Android Tablet

Standard file picker with multi-select support.

---

## Latency Reduction Strategies

### 1. Run-Ahead Emulation

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

### 2. Input Polling Optimization

- Poll input at frame start, not during vsync
- GameController framework callback-based input
- Direct hardware polling on supported controllers

### 3. Display Pipeline

```
Frame Ready → Metal Texture Upload → GPU Upscale → Present
                  │                       │
                  └── Use shared memory ──┘
```

**Key Metal Settings:**
- `presentsWithTransaction = false`
- `framebufferOnly = true`
- Use `MTLDrawable.presentAfterMinimumDuration()` for frame pacing

### 4. Audio Latency

- Target: 2 audio frames (~32ms)
- AVAudioEngine with minimal buffer size
- Sync audio to video, not vice versa

---

## 120fps Rendering Strategies

The NES runs at 60.0988fps. To achieve true 120fps:

### Frame Interpolation (Recommended)

```metal
// Simple temporal interpolation
float4 interpolatedFrame = mix(previousFrame, currentFrame, 0.5);
```

**Advanced:** Motion-compensated frame interpolation using optical flow.

---

## 4K Scaling

### Integer Scaling

NES: 256×240 → 4K: 3840×2160

Scale factor: 9× (2304×2160 centered in 4K frame)

```metal
float scale = min(floor(outputSize.x / inputSize.x), 
                  floor(outputSize.y / inputSize.y));
float2 scaledSize = inputSize * scale;
float2 offset = (outputSize - scaledSize) * 0.5;
```

### Aspect Ratio Correction

NES pixel aspect ratio: 8:7 (pixels are wider than tall)

---

## Directory Structure

```
~/Documents/NesCaster/
├── Profiles/
│   ├── {uuid-1}/                # Profile 1
│   │   ├── profile.json         # Profile metadata
│   │   ├── settings.json        # All settings
│   │   ├── controller.json      # Controller mapping
│   │   ├── ROMs/                # This profile's games
│   │   ├── Saves/               # Save state stacks
│   │   │   ├── {rom-hash}/
│   │   │   │   ├── stack.json   # Stack metadata
│   │   │   │   ├── save_001.state
│   │   │   │   ├── save_001.png
│   │   │   │   └── ...
│   │   │   └── autosaves/
│   │   └── CustomPictures/      # User-added profile pics
│   └── {uuid-2}/                # Profile 2
│       └── ...
└── Shared/
    └── ProfilePictures/         # Built-in picture library
```

---

## Development Phases

### Phase 1: Foundation ✅
- [x] Project structure setup
- [x] Basic SwiftUI UI shell
- [x] Metal rendering pipeline
- [x] Controller input handling

### Phase 2: Core Integration ✅
- [x] C bridge for Mesen
- [x] ROM loading (stub)
- [x] Frame output pipeline
- [x] Audio output (AVAudioEngine)

### Phase 2.5: Profile & Save System 🔄
- [ ] Profile data model & persistence
- [ ] Profile selection UI
- [ ] Animated profile pictures (Lottie)
- [ ] Per-profile ROM directories
- [ ] Per-profile controller mapping
- [ ] Stack-based save state system
- [ ] Auto-save feature
- [ ] Web server for content transfer

### Phase 3: Performance
- [ ] Integer scaling shader
- [ ] 120fps interpolation
- [ ] Run-ahead implementation
- [ ] Audio latency optimization

### Phase 4: Features
- [ ] Game library with cover art
- [ ] Settings persistence
- [ ] Cloud sync

### Phase 5: Polish
- [ ] UI animations
- [ ] Accessibility
- [ ] iPad/Android versions

---

## Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Input Latency | < 16ms | Input → Display delta |
| Frame Time | < 8.3ms | Metal frame render time |
| Audio Latency | < 32ms | Audio buffer size |
| Memory Usage | < 100MB | Instruments profiling |
| CPU Usage | < 30% | Single A-series core |
| Save State | < 100ms | Save/load operation time |
| Profile Switch | < 500ms | Full context switch |

---

## Resources

- [Mesen Source Code](https://github.com/SourMesen/Mesen2)
- [NES Dev Wiki](https://www.nesdev.org/wiki/)
- [Apple Metal Best Practices](https://developer.apple.com/metal/)
- [Lottie Animation Library](https://airbnb.io/lottie/)
- [Network Framework (Web Server)](https://developer.apple.com/documentation/network)
