//
//  SettingsView.swift
//  NesCaster
//
//  Settings with Liquid Glass UI
//

import SwiftUI

struct SettingsView: View {
    
    @ObservedObject var profileManager: ProfileManager
    
    // Display settings
    @AppStorage("scalingMode") private var scalingMode = "4K"
    @AppStorage("integerScaling") private var integerScaling = true
    @AppStorage("overscanCrop") private var overscanCrop = true
    
    // Performance settings
    @AppStorage("targetFrameRate") private var targetFrameRate = 120
    @AppStorage("frameInterpolation") private var frameInterpolation = true
    @AppStorage("runAheadFrames") private var runAheadFrames = 2
    @AppStorage("vsyncEnabled") private var vsyncEnabled = true
    
    // Audio settings
    @AppStorage("audioLatencyMs") private var audioLatencyMs = 32
    @AppStorage("masterVolume") private var masterVolume = 0.8
    
    // Save state settings
    @AppStorage("saveStateHistory") private var saveStateHistory = 5
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = true
    
    @State private var selectedSection: SettingSection = .display
    
    enum SettingSection: String, CaseIterable {
        case display = "Display"
        case performance = "Performance"
        case audio = "Audio"
        case saveStates = "Save States"
        case controllers = "Controllers"
        case profile = "Profile"
        case about = "About"
        
        var icon: String {
            switch self {
            case .display: return "tv"
            case .performance: return "gauge.high"
            case .audio: return "speaker.wave.3.fill"
            case .saveStates: return "square.stack.fill"
            case .controllers: return "gamecontroller.fill"
            case .profile: return "person.fill"
            case .about: return "info.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .display: return Color(red: 0.4, green: 0.6, blue: 0.95)
            case .performance: return Color(red: 0.95, green: 0.6, blue: 0.35)
            case .audio: return Color(red: 0.55, green: 0.85, blue: 0.55)
            case .saveStates: return Color(red: 0.7, green: 0.5, blue: 0.9)
            case .controllers: return Color(red: 0.95, green: 0.35, blue: 0.45)
            case .profile: return Color(red: 0.9, green: 0.75, blue: 0.3)
            case .about: return Color(red: 0.6, green: 0.7, blue: 0.75)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 40) {
            // Left sidebar - Glass navigation
            glassNavigationSidebar
            
            // Right content area - Glass panels
            glassContentArea
        }
    }
    
    // MARK: - Glass Navigation Sidebar
    
    private var glassNavigationSidebar: some View {
        VStack(spacing: 8) {
            ForEach(SettingSection.allCases, id: \.self) { section in
                GlassNavigationButton(
                    title: section.rawValue,
                    icon: section.icon,
                    color: section.color,
                    isSelected: selectedSection == section
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedSection = section
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 25, y: 10)
        )
        .frame(width: 280)
    }
    
    // MARK: - Glass Content Area
    
    private var glassContentArea: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Section header
                glassSectionHeader(selectedSection)
                    .padding(.bottom, 32)
                
                // Section content
                Group {
                    switch selectedSection {
                    case .display:
                        displaySettings
                    case .performance:
                        performanceSettings
                    case .audio:
                        audioSettings
                    case .saveStates:
                        saveStateSettings
                    case .controllers:
                        controllerSettings
                    case .profile:
                        profileSettings
                    case .about:
                        aboutSettings
                    }
                }
            }
            .padding(36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 25, y: 10)
        )
    }
    
    // MARK: - Glass Section Header
    
    private func glassSectionHeader(_ section: SettingSection) -> some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(section.color.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(section.color.opacity(0.5), lineWidth: 1)
                    )
                
                Image(systemName: section.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(section.color)
            }
            .shadow(color: section.color.opacity(0.3), radius: 15)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(section.rawValue)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text(sectionDescription(section))
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
    }
    
    private func sectionDescription(_ section: SettingSection) -> String {
        switch section {
        case .display: return "Resolution, scaling, and visual options"
        case .performance: return "Frame rate and optimization"
        case .audio: return "Sound output and latency"
        case .saveStates: return "Save management and history"
        case .controllers: return "Input devices and mapping"
        case .profile: return "Account and preferences"
        case .about: return "App information and credits"
        }
    }
    
    // MARK: - Display Settings
    
    private var displaySettings: some View {
        VStack(spacing: 20) {
            GlassSettingCard(
            title: "Scaling Mode",
                subtitle: "Choose output resolution",
                icon: "arrow.up.left.and.arrow.down.right"
            ) {
                Picker("", selection: $scalingMode) {
                    Text("Native (256×240)").tag("Native")
                    Text("HD (1280×720)").tag("HD")
                    Text("Full HD (1920×1080)").tag("FHD")
                    Text("4K (3840×2160)").tag("4K")
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
            
            GlassToggleCard(
            title: "Integer Scaling",
                subtitle: "Sharp pixels without blurring",
                icon: "square.grid.3x3",
                isOn: $integerScaling
            )
            
            GlassToggleCard(
                title: "Crop Overscan",
                subtitle: "Hide unused screen edges",
                icon: "crop",
                isOn: $overscanCrop
            )
        }
    }
    
    // MARK: - Performance Settings
    
    private var performanceSettings: some View {
        VStack(spacing: 20) {
            GlassSettingCard(
            title: "Target Frame Rate",
                subtitle: "Higher rates on supported displays",
                icon: "speedometer"
            ) {
                Picker("", selection: $targetFrameRate) {
                    Text("60 fps").tag(60)
                    Text("120 fps").tag(120)
                }
                .pickerStyle(.segmented)
            }
            
            GlassToggleCard(
            title: "Frame Interpolation",
                subtitle: "Smooth motion between frames",
                icon: "waveform.path.ecg",
                isOn: $frameInterpolation
            )
            
            GlassSettingCard(
                title: "Run-Ahead Frames",
                subtitle: "Reduce input latency",
            icon: "hare.fill"
        ) {
                Picker("", selection: $runAheadFrames) {
                    Text("Off").tag(0)
                    Text("1 frame").tag(1)
                    Text("2 frames").tag(2)
                    Text("3 frames").tag(3)
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
            
            GlassToggleCard(
            title: "VSync",
            subtitle: "Prevent screen tearing",
                icon: "display",
                isOn: $vsyncEnabled
            )
        }
    }
    
    // MARK: - Audio Settings
    
    private var audioSettings: some View {
        VStack(spacing: 20) {
            GlassSettingCard(
                title: "Master Volume",
                subtitle: "Audio output level",
                icon: "speaker.wave.3.fill"
            ) {
                Picker("", selection: $masterVolume) {
                    Text("Muted").tag(0.0)
                    Text("25%").tag(0.25)
                    Text("50%").tag(0.5)
                    Text("75%").tag(0.75)
                    Text("100%").tag(1.0)
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
            
            GlassSettingCard(
            title: "Audio Latency",
                subtitle: "Lower = more responsive, may crackle",
                icon: "clock.fill"
            ) {
                Picker("", selection: $audioLatencyMs) {
                    Text("16 ms").tag(16)
                    Text("32 ms").tag(32)
                    Text("48 ms").tag(48)
                    Text("64 ms").tag(64)
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
        }
    }
    
    // MARK: - Save State Settings
    
    private var saveStateSettings: some View {
        VStack(spacing: 20) {
            GlassSettingCard(
                title: "History Size",
                subtitle: "Number of save states to keep",
                icon: "clock.arrow.circlepath"
            ) {
                Picker("", selection: $saveStateHistory) {
                    Text("5 saves").tag(5)
                    Text("10 saves").tag(10)
                    Text("15 saves").tag(15)
                    Text("20 saves").tag(20)
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
            
            GlassToggleCard(
                title: "Auto-Save",
                subtitle: "Save progress after each level",
                icon: "arrow.clockwise.circle.fill",
                isOn: $autoSaveEnabled
            )
            
            // Info card
            HStack(spacing: 16) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Save History")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("New saves push oldest off the stack. Load presents dropdown of recent saves.")
                        .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Controller Settings
    
    private var controllerSettings: some View {
        VStack(spacing: 20) {
            // Connected controllers
            VStack(alignment: .leading, spacing: 16) {
                Text("Connected Controllers")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                GlassControllerCard(
                    name: "Siri Remote",
                    type: "Built-in",
                    status: .connected
                )
                
                GlassControllerCard(
                    name: "No External Controller",
                    type: "Pair via Settings",
                    status: .disconnected
                )
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.vertical, 10)
            
            // Controller settings
            GlassToggleCard(
                title: "Use Siri Remote",
                subtitle: "Use remote as NES controller",
                icon: "appletv.fill",
                isOn: .constant(true)
            )
            
            Button(action: {}) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.45))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Configure Button Mapping")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Customize controls for each profile")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
        }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Profile Settings
    
    private var profileSettings: some View {
        VStack(spacing: 20) {
            if let profile = profileManager.activeProfile {
                // Current profile info
                HStack(spacing: 20) {
                    let color = ProfilePictureManager.shared.getColor(for: profile.pictureID)
                    
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(color)
                            .frame(width: 64, height: 64)
                        
                        Text(String(profile.name.prefix(1)).uppercased())
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: color.opacity(0.4), radius: 15)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Created \(profile.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Button("Edit Profile") {
                        // Edit profile action
                    }
                    .buttonStyle(GlassPillButtonStyle())
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                
                Button(action: { profileManager.activeProfile = nil }) {
                    HStack(spacing: 14) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18))
                        Text("Switch Profile")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                
            } else {
                Text("No profile selected")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - About Settings
    
    private var aboutSettings: some View {
        VStack(spacing: 20) {
            // App info
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(.ultraThinMaterial)
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.35, blue: 0.45), Color(red: 0.85, green: 0.25, blue: 0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: Color(red: 0.95, green: 0.3, blue: 0.4).opacity(0.3), radius: 15)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("NesCaster")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Version 1.0.0 (Build 1)")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Premium NES Experience")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            
            // Feature badges
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 14) {
                GlassFeatureBadge(icon: "4k.tv.fill", text: "4K")
                GlassFeatureBadge(icon: "gauge.high", text: "120fps")
                GlassFeatureBadge(icon: "cpu", text: "Metal")
                GlassFeatureBadge(icon: "gamecontroller.fill", text: "MFi")
                GlassFeatureBadge(icon: "person.3.fill", text: "Profiles")
                GlassFeatureBadge(icon: "square.and.arrow.down.fill", text: "States")
            }
            
            // Credits
            VStack(alignment: .leading, spacing: 12) {
                Text("Powered By")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("Mesen NES Core • Metal Graphics • AVFoundation Audio")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.4))
            )
        }
    }
}

// MARK: - Glass Component Styles

struct GlassNavigationButton: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? color.opacity(0.3) : .clear)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? color : .white.opacity(0.6))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white.opacity(0.1) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isFocused ? color.opacity(0.6) : .clear, lineWidth: 2)
                    )
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

struct GlassSettingCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct GlassToggleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isOn ? .green : .white.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

struct GlassControllerCard: View {
    let name: String
    let type: String
    let status: ControllerStatus
    
    enum ControllerStatus {
        case connected, disconnected
    }
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 22))
                    .foregroundColor(status == .connected ? .green : .white.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(type)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Circle()
                .fill(status == .connected ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 10, height: 10)
                .shadow(color: status == .connected ? .green : .clear, radius: 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct GlassFeatureBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct GlassPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    SettingsView(profileManager: ProfileManager())
        .preferredColorScheme(.dark)
}
