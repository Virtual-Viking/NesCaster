//
//  AppIcons.swift
//  NesCaster
//
//  Centralized icon management
//  Update icon names here to change them throughout the app
//
//  Usage:
//  - For SF Symbols: Use the symbol name directly (e.g., "gamecontroller.fill")
//  - For custom icons: Add image to Assets.xcassets/Icons/ and use its name
//

import SwiftUI

// MARK: - App Icons

/// Centralized icon names for easy customization
/// To use custom icons:
/// 1. Add your icon to Assets.xcassets/Icons/
/// 2. Replace the SF Symbol name with your asset name
/// 3. Set `isSystemImage = false` for that icon
enum AppIcon: String, CaseIterable {
    
    // MARK: - Navigation
    case appLogo = "gamecontroller.fill"
    case library = "square.grid.2x2.fill"
    case settings = "gearshape.fill"
    case back = "chevron.left"
    case forward = "chevron.right"
    
    // MARK: - Game Library
    case recentGames = "clock.fill"
    case addGames = "plus.circle.fill"
    case importRom = "doc.badge.plus"
    case gameCartridge = "arcade.stick"
    case play = "play.fill"
    case playCircle = "play.circle.fill"
    
    // MARK: - Emulator Controls
    case pause = "pause.fill"
    case stop = "stop.fill"
    case reset = "arrow.counterclockwise"
    case saveState = "square.and.arrow.down.fill"
    case loadState = "square.and.arrow.up.fill"
    case quit = "xmark.circle.fill"
    case menu = "line.3.horizontal"
    
    // MARK: - Settings Categories
    case displaySettings = "display"
    case performanceSettings = "gauge.with.dots.needle.67percent"
    case audioSettings = "speaker.wave.3.fill"
    case controllerSettings = "gamecontroller"
    case aboutSettings = "info.circle.fill"
    
    // MARK: - Settings Items
    case scaling = "aspectratio.fill"
    case pixelGrid = "square.grid.3x3.fill"
    case overscan = "rectangle.dashed"
    case frameRate = "film.stack"
    case interpolation = "waveform.path"
    case runAhead = "hare.fill"
    case vsync = "rectangle.on.rectangle"
    case audioLatency = "waveform"
    case volume = "speaker.wave.2.fill"
    case buttonMapping = "square.grid.3x3.middle.filled"
    case siriRemote = "appletvremote.gen4.fill"
    case version = "tag.fill"
    case cpu = "cpu.fill"
    case renderer = "square.stack.3d.up.fill"
    
    // MARK: - Status Indicators
    case statusOK = "checkmark.circle.fill"
    case statusWarning = "exclamationmark.triangle.fill"
    case statusError = "xmark.octagon.fill"
    
    // MARK: - Media
    case fps120 = "speedometer"
    case resolution4K = "4k.tv.fill"
    case slider = "slider.horizontal.3"
    
    // MARK: - Icon Configuration
    
    /// Whether this icon is an SF Symbol (true) or custom asset (false)
    var isSystemImage: Bool {
        // By default, all icons are SF Symbols
        // Change specific cases to `false` when using custom assets
        switch self {
        // Example: If you add a custom app logo:
        // case .appLogo: return false
        default: return true
        }
    }
    
    /// Get the icon as a SwiftUI Image
    var image: Image {
        if isSystemImage {
            return Image(systemName: rawValue)
        } else {
            return Image(rawValue)
        }
    }
}

// MARK: - SwiftUI Extensions

extension Image {
    /// Create an image from AppIcon enum
    init(icon: AppIcon) {
        if icon.isSystemImage {
            self.init(systemName: icon.rawValue)
        } else {
            self.init(icon.rawValue)
        }
    }
}

extension Label where Title == Text, Icon == Image {
    /// Create a label with AppIcon
    init(_ title: String, icon: AppIcon) {
        if icon.isSystemImage {
            self.init(title, systemImage: icon.rawValue)
        } else {
            self.init {
                Text(title)
            } icon: {
                Image(icon.rawValue)
            }
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
struct AppIconsPreview: View {
    let columns = [GridItem(.adaptive(minimum: 100))]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(AppIcon.allCases, id: \.self) { icon in
                    VStack(spacing: 8) {
                        Image(icon: icon)
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                        
                        Text(String(describing: icon))
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    .frame(width: 100, height: 80)
                }
            }
            .padding()
        }
        .background(Color.black)
    }
}

#Preview {
    AppIconsPreview()
}
#endif
