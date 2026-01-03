//
//  SettingsView.swift
//  NesCaster
//
//  Comprehensive settings with per-profile support
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var appState: AppState
    @ObservedObject var profileManager: ProfileManager
    @State private var settings: ProfileSettings
    @State private var showingControllerMapping = false
    @State private var showingContentTransfer = false
    @State private var showingSwitchProfile = false
    
    init(profileManager: ProfileManager) {
        self.profileManager = profileManager
        // Load settings for active profile or use defaults
        if let profile = profileManager.activeProfile {
            _settings = State(initialValue: profileManager.loadSettings(for: profile))
        } else {
            _settings = State(initialValue: ProfileSettings())
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 50) {
                // Profile Section
                settingsSection(
                    title: "Profile",
                    icon: "person.crop.circle.fill",
                    content: profileSection
                )
                
                // Save States Section
                settingsSection(
                    title: "Save States",
                    icon: "square.and.arrow.down.fill",
                    content: saveStateSettings
                )
                
                // Display Settings
                settingsSection(
                    title: "Display",
                    icon: "display",
                    content: displaySettings
                )
                
                // Performance Settings
                settingsSection(
                    title: "Performance",
                    icon: "speedometer",
                    content: performanceSettings
                )
                
                // Audio Settings
                settingsSection(
                    title: "Audio",
                    icon: "speaker.wave.3.fill",
                    content: audioSettings
                )
                
                // Controller Settings
                settingsSection(
                    title: "Controller",
                    icon: "gamecontroller.fill",
                    content: controllerSettings
                )
                
                // Content Transfer (TV only)
                #if os(tvOS)
                settingsSection(
                    title: "Content Transfer",
                    icon: "arrow.down.circle.fill",
                    content: contentTransferSection
                )
                #endif
                
                // About
                settingsSection(
                    title: "About",
                    icon: "info.circle.fill",
                    content: aboutSection
                )
            }
            .padding(.bottom, 80)
        }
        .onChange(of: settings) { _, newSettings in
            saveSettings(newSettings)
        }
        .sheet(isPresented: $showingControllerMapping) {
            ControllerMappingView(profileManager: profileManager)
        }
        .sheet(isPresented: $showingContentTransfer) {
            ContentTransferView()
        }
    }
    
    // MARK: - Save Settings
    
    private func saveSettings(_ newSettings: ProfileSettings) {
        guard let profile = profileManager.activeProfile else { return }
        profileManager.saveSettings(newSettings, for: profile)
    }
    
    // MARK: - Section Builder
    
    private func settingsSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 0.95, green: 0.3, blue: 0.4))
                
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Profile Section
    
    @ViewBuilder
    private func profileSection() -> some View {
        if let profile = profileManager.activeProfile {
            let color = ProfilePictureManager.shared.getColor(for: profile.pictureID)
            
            SettingsRow(
                title: profile.name,
                subtitle: "\(profileManager.getROMCount(for: profile)) games • Active",
                icon: "person.fill"
            ) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                    
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            Button(action: { showingSwitchProfile = true }) {
                SettingsRow(
                    title: "Switch Profile",
                    subtitle: "Change to a different player",
                    icon: "person.2.fill"
                ) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
        } else {
            SettingsRow(
                title: "No Profile Selected",
                subtitle: "Please select a profile",
                icon: "person.fill.questionmark"
            ) {
                EmptyView()
            }
        }
    }
    
    // MARK: - Save State Settings
    
    @ViewBuilder
    private func saveStateSettings() -> some View {
        SettingsRow(
            title: "Save History Size",
            subtitle: "Number of save states to keep",
            icon: "clock.arrow.circlepath"
        ) {
            Picker("History Size", selection: $settings.saveHistorySize) {
                Text("5").tag(5)
                Text("10").tag(10)
                Text("15").tag(15)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Auto-Save",
            subtitle: "Automatically save during gameplay",
            icon: "arrow.clockwise.circle.fill"
        ) {
            Toggle("", isOn: $settings.autoSaveEnabled)
                .labelsHidden()
        }
        
        if settings.autoSaveEnabled {
            Divider().background(Color.white.opacity(0.1))
            
            SettingsRow(
                title: "Save on Level Complete",
                subtitle: "Auto-detect level completion",
                icon: "flag.checkered"
            ) {
                Toggle("", isOn: $settings.autoSaveOnLevelComplete)
                    .labelsHidden()
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            SettingsRow(
                title: "Save Interval",
                subtitle: settings.autoSaveIntervalMinutes == 0 ? "Disabled" : "Every \(settings.autoSaveIntervalMinutes) minutes",
                icon: "timer"
            ) {
                Picker("Interval", selection: $settings.autoSaveIntervalMinutes) {
                    Text("Off").tag(0)
                    Text("5 min").tag(5)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                }
                .pickerStyle(.menu)
            }
        }
    }
    
    // MARK: - Display Settings
    
    @ViewBuilder
    private func displaySettings() -> some View {
        SettingsRow(
            title: "Scaling Mode",
            subtitle: settings.scalingMode.rawValue,
            icon: "aspectratio.fill"
        ) {
            Picker("Scaling", selection: $settings.scalingMode) {
                ForEach(ProfileSettings.ScalingMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Scanlines",
            subtitle: "CRT-style scanline effect",
            icon: "line.3.horizontal"
        ) {
            Toggle("", isOn: $settings.showScanlines)
                .labelsHidden()
        }
        
        if settings.showScanlines {
            Divider().background(Color.white.opacity(0.1))
            
            SettingsRow(
                title: "Scanline Intensity",
                subtitle: "\(Int(settings.scanlineIntensity * 100))%",
                icon: "slider.horizontal.3"
            ) {
                // Slider would go here for tvOS
                Text("\(Int(settings.scanlineIntensity * 100))%")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "CRT Effect",
            subtitle: "Screen curvature and bloom",
            icon: "tv"
        ) {
            Toggle("", isOn: $settings.showCRTEffect)
                .labelsHidden()
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Show FPS Counter",
            subtitle: "Display frame rate overlay",
            icon: "gauge.with.dots.needle.bottom.50percent"
        ) {
            Toggle("", isOn: $settings.showFPSCounter)
                .labelsHidden()
        }
    }
    
    // MARK: - Performance Settings
    
    @ViewBuilder
    private func performanceSettings() -> some View {
        SettingsRow(
            title: "Target Frame Rate",
            subtitle: "Requires compatible display",
            icon: "film.stack"
        ) {
            Picker("Frame Rate", selection: $appState.targetFrameRate) {
                ForEach(AppState.FrameRate.allCases, id: \.self) { rate in
                    Text(rate.rawValue).tag(rate)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Frame Interpolation",
            subtitle: "Smooth 60→120fps conversion",
            icon: "waveform.path"
        ) {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Run-Ahead",
            subtitle: "Reduce input latency by 1 frame",
            icon: "hare.fill"
        ) {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
    }
    
    // MARK: - Audio Settings
    
    @ViewBuilder
    private func audioSettings() -> some View {
        SettingsRow(
            title: "Master Volume",
            subtitle: "\(Int(settings.masterVolume * 100))%",
            icon: "speaker.wave.2.fill"
        ) {
            // Volume control
            Text("\(Int(settings.masterVolume * 100))%")
                .foregroundColor(.white.opacity(0.5))
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Audio Latency",
            subtitle: settings.audioLatencyMode.rawValue,
            icon: "waveform"
        ) {
            Picker("Latency", selection: $settings.audioLatencyMode) {
                ForEach(ProfileSettings.AudioLatencyMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        // Audio Channels
        VStack(spacing: 0) {
            SettingsRow(
                title: "Audio Channels",
                subtitle: "Enable/disable NES audio channels",
                icon: "pianokeys"
            ) {
                EmptyView()
            }
            
            HStack(spacing: 16) {
                ChannelToggle(label: "Square 1", isOn: $settings.enableSquare1)
                ChannelToggle(label: "Square 2", isOn: $settings.enableSquare2)
                ChannelToggle(label: "Triangle", isOn: $settings.enableTriangle)
                ChannelToggle(label: "Noise", isOn: $settings.enableNoise)
                ChannelToggle(label: "DMC", isOn: $settings.enableDMC)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }
    
    // MARK: - Controller Settings
    
    @ViewBuilder
    private func controllerSettings() -> some View {
        SettingsRow(
            title: "Connected Controllers",
            subtitle: "1 controller connected",
            icon: "gamecontroller"
        ) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        Button(action: { showingControllerMapping = true }) {
            SettingsRow(
                title: "Button Mapping",
                subtitle: "Customize controller layout",
                icon: "square.grid.3x3.middle.filled"
            ) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Quick Save Button",
            subtitle: "Left Trigger (L2)",
            icon: "square.and.arrow.down"
        ) {
            Text("L2")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                )
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Quick Load Button",
            subtitle: "Right Trigger (R2)",
            icon: "square.and.arrow.up"
        ) {
            Text("R2")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.1))
                )
        }
    }
    
    // MARK: - Content Transfer Section
    
    @ViewBuilder
    private func contentTransferSection() -> some View {
        Button(action: { showingContentTransfer = true }) {
            SettingsRow(
                title: "Add ROMs & Pictures",
                subtitle: "Transfer files from your phone or computer",
                icon: "qrcode"
            ) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "How It Works",
            subtitle: "Scan QR code on same Wi-Fi network to upload files",
            icon: "questionmark.circle"
        ) {
            EmptyView()
        }
    }
    
    // MARK: - About Section
    
    @ViewBuilder
    private func aboutSection() -> some View {
        SettingsRow(
            title: "Version",
            subtitle: "NesCaster 1.0.0 (Build 1)",
            icon: "tag.fill"
        ) {
            EmptyView()
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Emulation Core",
            subtitle: "Mesen (Modified for low-latency)",
            icon: "cpu.fill"
        ) {
            EmptyView()
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Renderer",
            subtitle: "Metal 3 • GPU Accelerated • 120fps",
            icon: "square.stack.3d.up.fill"
        ) {
            EmptyView()
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Open Source Licenses",
            subtitle: "View third-party licenses",
            icon: "doc.text"
        ) {
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
        }
    }
}

// MARK: - Settings Row

struct SettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let accessory: () -> Accessory
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Labels
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Accessory
            accessory()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            isFocused ? Color.white.opacity(0.08) : Color.clear
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

// MARK: - Channel Toggle

struct ChannelToggle: View {
    let label: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isOn ? .white : .white.opacity(0.4))
                
                Circle()
                    .fill(isOn ? Color(red: 0.3, green: 0.8, blue: 0.4) : Color.white.opacity(0.2))
                    .frame(width: 12, height: 12)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isOn ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Controller Mapping View (Placeholder)

struct ControllerMappingView: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Text("Controller Mapping")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Press a button on your controller to remap it")
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Controller diagram would go here
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("Coming soon...")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .navigationTitle("Button Mapping")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Content Transfer View (Placeholder)

struct ContentTransferView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isServerRunning = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Text("Content Transfer")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    if isServerRunning {
                        // QR Code placeholder
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .frame(width: 200, height: 200)
                            .overlay(
                                Text("QR")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.black.opacity(0.3))
                            )
                        
                        Text("http://192.168.1.42:8080")
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("Open this URL on any device connected to the same Wi-Fi network")
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 60)
                    } else {
                        Image(systemName: "wifi")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Button(action: { isServerRunning = true }) {
                            Text("Start Transfer Server")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.9, green: 0.3, blue: 0.4))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Content")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView(profileManager: ProfileManager())
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
