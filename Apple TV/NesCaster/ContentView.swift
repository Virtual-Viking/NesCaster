//
//  ContentView.swift
//  NesCaster
//
//  Main content view with tab navigation
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileManager: ProfileManager
    @State private var selectedTab: Tab = .library
    @FocusState private var focusedTab: Tab?
    
    enum Tab: String, CaseIterable {
        case library = "Library"
        case settings = "Settings"
    }
    
    var body: some View {
        ZStack {
            // Atmospheric background
            backgroundGradient
            
            if appState.isEmulatorRunning {
                EmulatorView()
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isEmulatorRunning)
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Deep space gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.05, green: 0.03, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle accent glow
            RadialGradient(
                colors: [
                    Color(red: 0.8, green: 0.2, blue: 0.3).opacity(0.15),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 800
            )
            
            // Secondary accent
            RadialGradient(
                colors: [
                    Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.1),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding(.top, 60)
                .padding(.bottom, 40)
            
            // Tab Navigation
            tabBar
                .padding(.bottom, 30)
            
            // Content Area
            Group {
                switch selectedTab {
                case .library:
                    GameLibraryView()
                case .settings:
                    SettingsView(profileManager: profileManager)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 80)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 20) {
            // Logo
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.3, blue: 0.4),
                            Color(red: 0.85, green: 0.2, blue: 0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 0.95, green: 0.3, blue: 0.4).opacity(0.5), radius: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("NESCASTER")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                if let profile = profileManager.activeProfile {
                    Text("Playing as \(profile.name)")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)
                } else {
                    Text("Premium NES Experience")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)
                }
            }
            
            Spacer()
            
            // Profile indicator
            if let profile = profileManager.activeProfile {
                profileIndicator(profile)
            }
            
            // Performance badge
            performanceBadge
        }
    }
    
    private func profileIndicator(_ profile: Profile) -> some View {
        let color = ProfilePictureManager.shared.getColor(for: profile.pictureID)
        
        return Button(action: switchProfile) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                    
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Switch Profile")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private var performanceBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: .green, radius: 4)
            
            Text("4K • 120fps")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 40) {
            ForEach(Tab.allCases, id: \.self) { tab in
                TabButton(
                    title: tab.rawValue,
                    icon: tab == .library ? "square.grid.2x2.fill" : "gearshape.fill",
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                }
                .focused($focusedTab, equals: tab)
            }
        }
    }
    
    // MARK: - Actions
    
    private func switchProfile() {
        profileManager.activeProfile = nil
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.white.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.25), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(ProfileManager())
}
