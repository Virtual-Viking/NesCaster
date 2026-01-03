h bjhb# 🎨 NesCaster Icon Reference

This document lists all icons used in the app and how to customize them.

## Quick Start

1. Add your custom icon to `Assets.xcassets/Icons/`
2. Edit `AppIcons.swift` and change the icon's `rawValue` to your asset name
3. Set `isSystemImage` to `false` for that icon

## Current Icons (SF Symbols)

### Navigation
| Case | SF Symbol | Used In |
|------|-----------|---------|
| `appLogo` | `gamecontroller.fill` | Header |
| `library` | `square.grid.2x2.fill` | Tab bar |
| `settings` | `gearshape.fill` | Tab bar |
| `back` | `chevron.left` | Navigation |
| `forward` | `chevron.right` | Settings rows |

### Game Library
| Case | SF Symbol | Used In |
|------|-----------|---------|
| `recentGames` | `clock.fill` | Section header |
| `addGames` | `plus.circle.fill` | Section header |
| `importRom` | `doc.badge.plus` | Add games button |
| `gameCartridge` | `arcade.stick` | Game card placeholder |
| `play` | `play.fill` | Play button |
| `playCircle` | `play.circle.fill` | Game card hover |

### Emulator Controls
| Case | SF Symbol | Used In |
|------|-----------|---------|
| `pause` | `pause.fill` | Pause menu |
| `stop` | `stop.fill` | Stop button |
| `reset` | `arrow.counterclockwise` | Reset button |
| `saveState` | `square.and.arrow.down.fill` | Save button |
| `loadState` | `square.and.arrow.up.fill` | Load button |
| `quit` | `xmark.circle.fill` | Quit button |
| `menu` | `line.3.horizontal` | Menu button |

### Settings Categories
| Case | SF Symbol | Used In |
|------|-----------|---------|
| `displaySettings` | `display` | Settings section |
| `performanceSettings` | `gauge.with.dots.needle.67percent` | Settings section |
| `audioSettings` | `speaker.wave.3.fill` | Settings section |
| `controllerSettings` | `gamecontroller` | Settings section |
| `aboutSettings` | `info.circle.fill` | Settings section |

### Settings Items
| Case | SF Symbol | Used In |
|------|-----------|---------|
| `scaling` | `aspectratio.fill` | Display settings |
| `pixelGrid` | `square.grid.3x3.fill` | Display settings |
| `overscan` | `rectangle.dashed` | Display settings |
| `frameRate` | `film.stack` | Performance settings |
| `interpolation` | `waveform.path` | Performance settings |
| `runAhead` | `hare.fill` | Performance settings |
| `vsync` | `rectangle.on.rectangle` | Performance settings |
| `audioLatency` | `waveform` | Audio settings |
| `volume` | `speaker.wave.2.fill` | Audio settings |
| `buttonMapping` | `square.grid.3x3.middle.filled` | Controller settings |
| `siriRemote` | `appletvremote.gen4.fill` | Controller settings |
| `version` | `tag.fill` | About section |
| `cpu` | `cpu.fill` | About section |
| `renderer` | `square.stack.3d.up.fill` | About section |

### Status Indicators
| Case | SF Symbol | Used In |
|------|-----------|---------|
| `statusOK` | `checkmark.circle.fill` | Status indicator |
| `statusWarning` | `exclamationmark.triangle.fill` | Warnings |
| `statusError` | `xmark.octagon.fill` | Errors |

### Media Badges
| Case | SF Symbol | Used In |
|------|-----------|---------|
| `fps120` | `speedometer` | Performance badge |
| `resolution4K` | `4k.tv.fill` | Resolution badge |
| `slider` | `slider.horizontal.3` | Slider controls |

---

## Adding Custom Icons

### Step 1: Prepare Your Icon

- **Format**: PDF (vector) or PNG
- **Sizes for tvOS**:
  - 1x: Base size (e.g., 400×400)
  - 2x: Double size (e.g., 800×800)
- **Style**: Match SF Symbols weight for consistency

### Step 2: Add to Asset Catalog

1. Open `Assets.xcassets` in Xcode
2. Navigate to `Icons` folder
3. Right-click → New Image Set
4. Name it (e.g., "custom-logo")
5. Drag your icon files into the slots

### Step 3: Update AppIcons.swift

```swift
enum AppIcon: String, CaseIterable {
    // Change from SF Symbol to custom asset
    case appLogo = "custom-logo"  // was "gamecontroller.fill"
    
    var isSystemImage: Bool {
        switch self {
        case .appLogo: return false  // Custom asset
        default: return true          // SF Symbol
        }
    }
}
```

### Step 4: Done!

All views using `AppIcon.appLogo` will now show your custom icon.

---

## Usage in SwiftUI

```swift
// Using the image directly
Image(icon: .appLogo)
    .font(.system(size: 24))

// Using with Label
Label("Library", icon: .library)

// Getting the raw SF Symbol name
let symbolName = AppIcon.play.rawValue  // "play.fill"
```

---

## SF Symbols Browser

Download Apple's SF Symbols app to browse all available system icons:
https://developer.apple.com/sf-symbols/
