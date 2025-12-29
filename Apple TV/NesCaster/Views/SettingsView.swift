//
//  SettingsView.swift
//  NesCaster
//

import SwiftUI

struct SettingsView: View {
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 50) {
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
                
                // About
                settingsSection(
                    title: "About",
                    icon: "info.circle.fill",
                    content: aboutSection
                )
            }
            .padding(.bottom, 80)
        }
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
    
    // MARK: - Display Settings
    
    @ViewBuilder
    private func displaySettings() -> some View {
        SettingsRow(
            title: "Scaling Mode",
            subtitle: appState.scalingMode.rawValue,
            icon: "aspectratio.fill"
        ) {
            Picker("Scaling", selection: $appState.scalingMode) {
                ForEach(AppState.ScalingMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Integer Scaling",
            subtitle: "Pixel-perfect rendering without blur",
            icon: "square.grid.3x3.fill"
        ) {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Overscan",
            subtitle: "Hide border artifacts",
            icon: "rectangle.dashed"
        ) {
            Toggle("", isOn: .constant(true))
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
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "VSync",
            subtitle: "Prevent screen tearing",
            icon: "display"
        ) {
            Toggle("", isOn: .constant(false))
                .labelsHidden()
        }
    }
    
    // MARK: - Audio Settings
    
    @ViewBuilder
    private func audioSettings() -> some View {
        SettingsRow(
            title: "Audio Latency",
            subtitle: "Lower = faster response, may cause crackles",
            icon: "waveform"
        ) {
            Picker("Latency", selection: $appState.audioLatencyMode) {
                ForEach(AppState.AudioLatency.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Master Volume",
            subtitle: "System audio level",
            icon: "speaker.wave.2.fill"
        ) {
            // Volume control would go here
            Image(systemName: "slider.horizontal.3")
                .foregroundColor(.white.opacity(0.5))
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
        
        SettingsRow(
            title: "Button Mapping",
            subtitle: "Customize controller layout",
            icon: "square.grid.3x3.middle.filled"
        ) {
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.3))
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Siri Remote",
            subtitle: "Use as NES controller",
            icon: "appletvremote.gen4.fill"
        ) {
            Toggle("", isOn: .constant(true))
                .labelsHidden()
        }
    }
    
    // MARK: - About Section
    
    @ViewBuilder
    private func aboutSection() -> some View {
        SettingsRow(
            title: "Version",
            subtitle: "NesCaster 1.0.0",
            icon: "tag.fill"
        ) {
            EmptyView()
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Emulation Core",
            subtitle: "Mesen (Modified)",
            icon: "cpu.fill"
        ) {
            EmptyView()
        }
        
        Divider().background(Color.white.opacity(0.1))
        
        SettingsRow(
            title: "Renderer",
            subtitle: "Metal 3 • GPU Accelerated",
            icon: "square.stack.3d.up.fill"
        ) {
            EmptyView()
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

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}

