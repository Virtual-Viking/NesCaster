# 🎮 NesCaster

**Premium NES Emulator for Modern Platforms**

A high-performance Nintendo Entertainment System emulator designed for Apple TV, iPad, and Android with a focus on:

- ⚡ **Sub-frame latency** — Faster response than original hardware
- 🖥️ **4K crisp graphics** — Pixel-perfect integer scaling
- 🎬 **True 120fps** — Smooth motion without frame doubling
- 👥 **Multi-profile support** — Netflix-style profile switching
- 🎨 **Beautiful UI** — Modern, elegant interface
- 🔮 **Liquid Glass UI** — Apple's latest design language (Apple TV & iPad)

---

## ✨ Key Features

### 👥 Profile System (Netflix-Style)
- **Up to 4 profiles** per device
- Each profile has isolated:
  - ROM/game collection
  - Settings & preferences
  - Controller mappings
  - Save states & history
- **Animated profile pictures** from built-in library
- **Easy content transfer** via web interface (TV) or file browser (iPad/Android)

### 💾 Smart Save States
- **History-based saves** — Never lose progress again!
- Configurable history size (5, 10, or 15 slots)
- **Instant save** — One button press
- **Visual load picker** — See recent saves with timestamps
- **Auto-save** after level completion
- Oldest saves automatically pruned

### 🎮 Per-Profile Controller Support
- Remember paired controllers per profile
- Custom button remapping saved per profile
- Support for all major controllers

### 📲 Easy Content Transfer
| Platform | Method |
|----------|--------|
| Apple TV / Android TV | Web interface (scan QR code on same network) |
| iPad / Android Tablet | Native file browser |

---

## 📁 Project Structure

```
NesCaster/
├── Android/              # Android app (Kotlin + Jetpack Compose)
├── iPad/                 # iOS/iPadOS app (SwiftUI)
├── Apple TV/             # tvOS app (SwiftUI + Metal) — Primary target
│   └── NesCaster/
│       ├── Core/         # Emulator core & bridges
│       ├── Views/        # SwiftUI views
│       ├── Rendering/    # Metal renderer & shaders
│       ├── Profiles/     # Profile management
│       ├── SaveStates/   # Save state system
│       ├── WebServer/    # Content transfer server
│       └── Resources/    # Assets & profile pictures
├── Research/             # Technical documentation
└── Shared/               # Cross-platform code
    ├── mesen/            # Mesen2 NES emulator core
    └── ProfilePictures/  # Animated SVG/Lottie library
```

---

## 🚀 Getting Started

### Requirements

- **macOS** Sonoma 14+ 
- **Xcode** 15+
- **Apple TV 4K** (3rd gen recommended for 120fps)
- **Apple Developer Account** (free for simulator, $99/year for device)

### Setup

1. **Install Xcode** from the App Store

2. **Open the project:**
   ```bash
   open "Apple TV/NesCaster.xcodeproj"
   ```

3. **Install tvOS Simulator:**
   - Xcode → Settings → Platforms → Download tvOS

4. **Run on Simulator:**
   - Select "Apple TV 4K" simulator
   - Press ⌘R to build and run

### Deploying to Physical Apple TV

To install and test on your Apple TV 4K 3rd gen device:

📖 **See detailed instructions:** [`Apple TV/DEPLOYMENT_GUIDE.md`](Apple%20TV/DEPLOYMENT_GUIDE.md)

**Quick steps:**
1. Enable **Developer Mode** on your Apple TV (Settings → Privacy and Security)
2. Connect Apple TV to Xcode (Window → Devices and Simulators)
3. Select your Apple TV as the build destination
4. Press ⌘R to build and install

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Profile Selection                           │
│              (Netflix-style animated avatars)                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      SwiftUI Interface                           │
│  ┌──────────┐  ┌──────────────┐  ┌────────────┐  ┌───────────┐  │
│  │ Library  │  │   Emulator   │  │  Settings  │  │  Transfer │  │
│  │   View   │  │     View     │  │    View    │  │    View   │  │
│  └──────────┘  └──────────────┘  └────────────┘  └───────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │                │               │               │
         ▼                ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  Profile    │  │  Emulator   │  │  Controller │  │    Web      │
│  Manager    │  │    Core     │  │   Manager   │  │   Server    │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
         │                │               │
         └────────────────┼───────────────┘
                          ▼
              ┌─────────────────────┐
              │   SaveState Manager │
              │   (Stack + History) │
              └─────────────────────┘
```

---

## ⚡ Performance Features

### Low Latency
- **Run-ahead emulation** — Predicts future frames to reduce input lag
- **Direct input polling** — Bypasses OS input buffering
- **Zero-copy textures** — Shared memory between CPU and GPU

### High Frame Rate
- **Frame interpolation** — Generates smooth intermediate frames
- **Metal 3 optimization** — Native GPU acceleration
- **VRR support** — Variable refresh rate when available

### Sharp Scaling
- **Integer scaling** — No blur or interpolation artifacts
- **Pixel aspect correction** — Proper 8:7 NES pixel ratio
- **Optional CRT effects** — Scanlines, curvature, bloom

---

## 🔮 Liquid Glass UI (Apple Devices)

NesCaster features Apple's newest **Liquid Glass** design language on Apple TV and iPad:

- **Glassmorphic surfaces** — Translucent panels with depth and blur
- **Animated orb backgrounds** — Subtle, colorful ambient lighting
- **Glass cards & buttons** — Material-based components with elegant borders
- **Smooth animations** — Spring-physics transitions and hover effects
- **Focus states** — Beautiful glow effects when navigating with remote/keyboard

| Component | Glass Treatment |
|-----------|-----------------|
| Profile Selection | Full-screen glass with animated color orbs |
| Game Library | Glass game cards with colored accents |
| Settings | Glass sidebar navigation + glass panels |
| Tab Bar | Frosted glass capsule with selection indicator |
| Buttons | Translucent pills with gradient borders |

---

## 🎮 Controller Support

| Controller | Support |
|------------|---------|
| Siri Remote | ✅ Touch surface + buttons |
| PlayStation 5 DualSense | ✅ Full support + haptics |
| Xbox Series X Controller | ✅ Full support |
| MFi Controllers | ✅ Full support |
| 8BitDo Controllers | ✅ Bluetooth connection |

---

## 📋 Roadmap

### Phase 1: Foundation ✅
- [x] Project setup
- [x] Basic UI shell (Library, Settings, Emulator views)
- [x] Metal rendering pipeline
- [x] Controller input system
- [x] Asset catalog configuration
- [x] Centralized icon management

### Phase 2: Core Integration ✅
- [x] C/Objective-C++ bridge interface
- [x] NESEmulatorCore to MesenBridge connection
- [x] Frame buffer → Metal renderer pipeline
- [x] Controller input wiring
- [x] Demo mode (animated test patterns)
- [x] Audio output with AVAudioEngine
- [ ] Compile actual Mesen core for tvOS

### Phase 2.5: Profile & Save System ✅
- [x] Profile data model & persistence
- [x] Netflix-style profile selection UI
- [x] **Liquid Glass UI** (Apple TV & iPad)
- [x] Stack-based save state history
- [x] Save state load picker UI with screenshots
- [x] Per-profile controller pairing & remapping
- [x] Controller mapping UI
- [x] Web server for content transfer (TV)
- [x] Transfer UI with QR code
- [ ] Animated profile picture library (Lottie)
- [ ] Auto-save level detection

### Phase 3: Performance
- [ ] Integer scaling shader
- [ ] 120fps frame interpolation
- [ ] Run-ahead implementation
- [ ] Audio latency optimization

### Phase 4: Features
- [ ] Game library with cover art
- [ ] Settings persistence
- [ ] Cloud sync across devices

### Phase 5: Polish & Expansion
- [ ] UI animations and transitions
- [ ] Accessibility features
- [ ] iPad version
- [ ] Android version

---

## 🔧 Development

### Adding Profile Pictures

Drop animated (Lottie JSON) or static (SVG/PNG) images into:
```
Shared/ProfilePictures/
├── Animated/     # Lottie JSON files
└── Static/       # SVG or PNG files
```

The app automatically discovers and lists them in the profile picture picker.

### Building Mesen Core

```bash
cd Shared/mesen
# See Research/TECHNICAL_ARCHITECTURE.md for compilation instructions
```

### Running Tests

```bash
xcodebuild test -project "Apple TV/NesCaster.xcodeproj" -scheme NesCaster
```

---

## 📜 License

This project uses the Mesen emulator core which is licensed under GPL-3.0.

---

## 🙏 Acknowledgments

- [Mesen](https://github.com/SourMesen/Mesen2) — High-accuracy NES/SNES/GB emulator
- [NESDev Wiki](https://www.nesdev.org/) — NES technical documentation
- [Lottie](https://airbnb.io/lottie/) — Animation library for profile pictures
