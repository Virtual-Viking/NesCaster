# 🎯 NesCaster Features Specification

This document details all planned features for NesCaster with implementation notes.

---

## 👥 Profile System

### Overview
Netflix-style profile system allowing up to 4 users per device, each with completely isolated data.

### Profile Data Model

```swift
struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var pictureID: String           // Reference to profile picture
    var createdAt: Date
    var lastUsedAt: Date
    
    // Isolated data paths
    var romsDirectory: URL          // ~/Profiles/{id}/ROMs/
    var savesDirectory: URL         // ~/Profiles/{id}/Saves/
    var settingsPath: URL           // ~/Profiles/{id}/settings.json
    var controllerMappingPath: URL  // ~/Profiles/{id}/controller.json
}
```

### Profile Selection UI

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                         Who's Playing?                           │
│                                                                  │
│    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    │
│    │ ◉     ◉│    │         │    │         │    │    +    │    │
│    │    ▽   │    │  (img)  │    │  (img)  │    │   Add   │    │
│    │  \___/ │    │         │    │         │    │ Profile │    │
│    └─────────┘    └─────────┘    └─────────┘    └─────────┘    │
│       Player 1       Player 2       Kid           (empty)       │
│                                                                  │
│                     [ Manage Profiles ]                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Profile Features

| Feature | Description |
|---------|-------------|
| **Animated Avatars** | Lottie JSON animations play on hover/focus |
| **Isolated ROMs** | Each profile sees only their games |
| **Isolated Saves** | Save states never mix between profiles |
| **Isolated Settings** | Video, audio, controller all per-profile |
| **Quick Switch** | Long-press Menu to switch profiles |

---

## 🖼️ Profile Picture Library

### Folder Structure

```
Shared/ProfilePictures/
├── Animated/                    # Lottie JSON files
│   ├── mario_jump.json
│   ├── link_sword.json
│   ├── samus_visor.json
│   └── megaman_charge.json
├── Static/                      # PNG/SVG images
│   ├── nes_controller.png
│   ├── 8bit_heart.png
│   └── pixel_star.png
└── manifest.json                # Metadata for all pictures
```

### Manifest Format

```json
{
  "pictures": [
    {
      "id": "mario_jump",
      "name": "Jumping Mario",
      "type": "animated",
      "file": "Animated/mario_jump.json",
      "category": "characters"
    },
    {
      "id": "nes_controller",
      "name": "NES Controller",
      "type": "static",
      "file": "Static/nes_controller.png",
      "category": "retro"
    }
  ],
  "categories": ["characters", "retro", "abstract", "custom"]
}
```

### Adding Custom Pictures

Users can add their own profile pictures via the web interface or file transfer. Custom pictures are stored in:
```
~/Profiles/{profileID}/CustomPictures/
```

---

## 📲 Content Transfer System

### Apple TV / Android TV: Web Server

When user enters "Add Content" mode:

1. App starts local HTTP server on port 8080
2. Displays IP address and QR code
3. User scans QR or enters URL on phone/computer
4. Web UI allows:
   - Upload ROM files (.nes)
   - Upload profile pictures (.png, .json)
   - View current library
   - Delete files

```
┌─────────────────────────────────────────────────────────────────┐
│                      Add Games & Pictures                        │
│                                                                  │
│              ┌───────────────────────┐                          │
│              │  █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█  │                          │
│              │  █ ▄▄▄▄▄ █▀█ █▄█ █  │                          │
│              │  █ █   █ █▄▀ █▄▄▄█  │  ← QR Code                │
│              │  █ ▀▀▀▀▀ █ █▀█▀▀▀█  │                          │
│              │  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀  │                          │
│              └───────────────────────┘                          │
│                                                                  │
│              Open on your phone or computer:                     │
│                                                                  │
│                   http://192.168.1.42:8080                       │
│                                                                  │
│              Connected to same Wi-Fi network                     │
│                                                                  │
│                        [ Done ]                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Web UI Features

```html
┌─────────────────────────────────────────────────────────────────┐
│  NesCaster - Player 1's Library                     [Connected] │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📁 Upload Files                                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Drag & drop ROM files (.nes) or profile pictures here      ││
│  │                    or click to browse                        ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  🎮 Current ROMs (3)                                            │
│  ├── Super Mario Bros.nes                    [Delete]           │
│  ├── Legend of Zelda.nes                     [Delete]           │
│  └── Metroid.nes                             [Delete]           │
│                                                                  │
│  🖼️ Profile Pictures (1 custom)                                 │
│  └── my_avatar.png                           [Delete]           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### iPad / Android Tablet

Native file picker with multi-select support:
- Standard document picker
- iCloud Drive / Google Drive integration
- Files app integration

---

## 🎮 Per-Profile Controller System

### Controller Pairing

When a controller connects for the first time:
1. Prompt: "Pair this controller to [Profile Name]?"
2. If yes: Save controller identifier to profile
3. Future connections auto-select profile

### Controller Mapping Data

```swift
struct ControllerMapping: Codable {
    var profileID: UUID
    var controllerID: String        // GCController.vendorName + identifier
    var controllerType: String      // "DualSense", "Xbox", "MFi", etc.
    
    // NES button mappings
    var buttonA: ControllerButton
    var buttonB: ControllerButton
    var buttonStart: ControllerButton
    var buttonSelect: ControllerButton
    var dpadUp: ControllerButton
    var dpadDown: ControllerButton
    var dpadLeft: ControllerButton
    var dpadRight: ControllerButton
    
    // Special mappings
    var quickSave: ControllerButton    // Default: L1
    var quickLoad: ControllerButton    // Default: R1
    var openMenu: ControllerButton     // Default: Menu/Options
    var turboA: ControllerButton?      // Optional
    var turboB: ControllerButton?      // Optional
}

enum ControllerButton: String, Codable {
    case buttonA, buttonB, buttonX, buttonY
    case l1, l2, r1, r2
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case leftStickUp, leftStickDown, leftStickLeft, leftStickRight
    case menu, options
}
```

---

## 💾 Smart Save State System

### The Problem (Why This Feature Exists)

> "I used bumper buttons for save/load. When my character died, I accidentally hit SAVE instead of LOAD. Now my only save state is at the death screen. All progress lost."

### The Solution: Stack-Based Save History

Instead of single save slots, each save pushes to a stack. Loading shows recent history.

### Save State Stack

```
┌─────────────────────────────────────────┐
│           Save State Stack              │
├─────────────────────────────────────────┤
│  [0] 2:34 PM - Level 3-2 (Latest)  ←── Load picks this by default
│  [1] 2:31 PM - Level 3-1               
│  [2] 2:28 PM - Level 2-4               
│  [3] 2:25 PM - Level 2-3               
│  [4] 2:20 PM - Level 2-2 (Oldest)  ←── Will be deleted on next save
└─────────────────────────────────────────┘
         ↑
    Stack Size: 5 (configurable: 5/10/15)
```

### Save State Data Model

```swift
struct SaveStateEntry: Identifiable, Codable {
    let id: UUID
    let gameID: String              // ROM hash/identifier
    let profileID: UUID
    let timestamp: Date
    let screenshotData: Data        // Thumbnail for UI
    let stateData: Data             // Actual emulator state
    let metadata: SaveMetadata
}

struct SaveMetadata: Codable {
    var gameName: String
    var playTime: TimeInterval      // Total play time at save
    var levelHint: String?          // "World 3-2" if detectable
    var isAutoSave: Bool
}
```

### User Flow: Saving

```
User presses SAVE button
         │
         ▼
┌─────────────────────┐
│  ✓ State Saved!     │  ← Toast notification (0.5s)
│  Slot 1 of 5        │
└─────────────────────┘
         │
         ▼
  (Game continues immediately - no interruption)
```

### User Flow: Loading

```
User presses LOAD button
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Load Save State                             │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  [Screenshot]│  │  [Screenshot]│  │  [Screenshot]│          │
│  │              │  │              │  │              │          │
│  │  2:34 PM     │  │  2:31 PM     │  │  2:28 PM     │          │
│  │  Level 3-2   │  │  Level 3-1   │  │  Level 2-4   │          │
│  │  ★ Latest    │  │              │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│       [1]              [2]              [3]                     │
│                                                                  │
│   Press A to load  •  Press B to cancel  •  ←→ to browse        │
└─────────────────────────────────────────────────────────────────┘
```

### Auto-Save Feature

**Level Detection Methods:**

1. **RAM Watch** — Monitor known memory addresses for level indicators
2. **Screen Hash** — Detect "stage clear" / "level complete" screens  
3. **Music Detection** — Level complete jingles trigger auto-save
4. **Time-Based** — Auto-save every N minutes as fallback

**Auto-Save Settings:**

```swift
struct AutoSaveSettings: Codable {
    var enabled: Bool = true
    var onLevelComplete: Bool = true
    var intervalMinutes: Int = 5      // 0 = disabled
    var separateFromManual: Bool = true  // Don't count toward stack limit
}
```

### Settings UI

```
┌─────────────────────────────────────────────────────────────────┐
│  Save State Settings                                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  History Size                                                    │
│  ○ 5 saves    ● 10 saves    ○ 15 saves                          │
│                                                                  │
│  ─────────────────────────────────────────────                  │
│                                                                  │
│  Auto-Save                                                       │
│  [✓] Enable auto-save                                           │
│  [✓] Save on level complete                                     │
│  [ ] Save every 5 minutes                                       │
│                                                                  │
│  ─────────────────────────────────────────────                  │
│                                                                  │
│  Quick Buttons                                                   │
│  Save: L1 (Left Shoulder)               [Remap]                 │
│  Load: R1 (Right Shoulder)              [Remap]                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📂 Directory Structure (Per Profile)

```
~/Documents/NesCaster/
├── Profiles/
│   ├── {uuid-1}/                    # Profile 1
│   │   ├── profile.json             # Profile metadata
│   │   ├── settings.json            # All settings
│   │   ├── controller.json          # Controller mapping
│   │   ├── ROMs/                    # This profile's games
│   │   │   ├── Super Mario Bros.nes
│   │   │   └── Zelda.nes
│   │   ├── Saves/                   # Save state stacks
│   │   │   ├── {rom-hash}/
│   │   │   │   ├── stack.json       # Stack metadata
│   │   │   │   ├── save_001.state
│   │   │   │   ├── save_001.png     # Screenshot
│   │   │   │   ├── save_002.state
│   │   │   │   └── save_002.png
│   │   │   └── autosaves/
│   │   │       └── ...
│   │   └── CustomPictures/          # User-added profile pics
│   │       └── my_avatar.png
│   ├── {uuid-2}/                    # Profile 2
│   │   └── ...
│   └── {uuid-3}/                    # Profile 3
│       └── ...
└── Shared/
    └── ProfilePictures/             # Built-in picture library
        ├── Animated/
        └── Static/
```

---

## 🔧 Implementation Priority

### Phase 2.5a: Profile Foundation
1. Profile data model
2. Profile persistence (JSON)
3. Profile selection UI
4. Profile creation/deletion

### Phase 2.5b: Profile Pictures
1. Picture library folder structure
2. Static picture support
3. Lottie animation support
4. Picture picker UI

### Phase 2.5c: Isolated Data
1. Per-profile ROM directories
2. Per-profile settings
3. Settings migration for existing users

### Phase 2.5d: Controller Per Profile
1. Controller identification
2. Pairing flow
3. Mapping storage
4. Mapping editor UI

### Phase 2.5e: Save State Stack
1. Stack data model
2. Save/Load logic
3. History UI
4. Screenshot capture

### Phase 2.5f: Auto-Save
1. Level detection (basic time-based)
2. Auto-save triggering
3. Settings UI

### Phase 2.5g: Content Transfer
1. Web server (Apple TV)
2. Web UI (HTML/JS)
3. File upload handling
4. Native file picker (iPad)

---

## 📝 Notes

- All profile data uses `Codable` for easy JSON serialization
- Screenshots are compressed JPEG (quality 0.7) for space efficiency
- Save states use `NSKeyedArchiver` compatible format
- Web server uses `NWListener` (Network framework) for modern networking
- Lottie animations via `lottie-ios` SPM package

