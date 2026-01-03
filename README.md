# 🎮 NesCaster

**Premium NES Emulator for Modern Platforms**

A high-performance Nintendo Entertainment System emulator designed for Apple TV, iPad, and Android with a focus on:

- ⚡ **Sub-frame latency** — Faster response than original hardware
- 🖥️ **4K crisp graphics** — Pixel-perfect integer scaling
- 🎬 **True 120fps** — Smooth motion without frame doubling
- 🎨 **Beautiful UI** — Modern, elegant interface

---

## 📁 Project Structure

```
NesCaster/
├── Android/          # Android app (Kotlin + Jetpack Compose)
├── iPad/             # iOS/iPadOS app (SwiftUI)
├── Apple TV/         # tvOS app (SwiftUI + Metal) — Primary target
├── Research/         # Technical documentation
└── Shared/           # Cross-platform code
    └── mesen/        # Mesen2 NES emulator core
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

### Device Testing

1. Enable Developer Mode on Apple TV
2. Pair Apple TV in Xcode (Window → Devices and Simulators)
3. Select your Apple TV as the run destination
4. Build and run (⌘R)

---

## 🏗️ Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  SwiftUI    │────▶│  Mesen      │────▶│   Metal     │
│  Interface  │     │  NES Core   │     │  Renderer   │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Game       │     │  Frame      │     │  4K Output  │
│  Controller │     │  Buffer     │     │  @ 120fps   │
└─────────────┘     └─────────────┘     └─────────────┘
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

## 🎮 Controller Support

| Controller | Support |
|------------|---------|
| Siri Remote | ✅ Touch surface + buttons |
| PlayStation 5 DualSense | ✅ Full support |
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

### Phase 2: Core Integration 🔄 (In Progress)
- [ ] Compile Mesen core for tvOS
- [ ] Create C bridge interface
- [ ] ROM loading
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

### Phase 5: Polish & Expansion
- [ ] UI animations and transitions
- [ ] Accessibility features
- [ ] iPad version
- [ ] Android version

---

## 🔧 Development

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

