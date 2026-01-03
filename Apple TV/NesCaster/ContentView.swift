//
//  ContentView.swift
//  NesCaster
//
//  Main content view with Liquid Glass UI
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
            // Liquid Glass background
            liquidGlassBackground
            
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
    
    // MARK: - Liquid Glass Background
    
    private var liquidGlassBackground: some View {
        ZStack {
            // Deep base
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.06),
                    Color(red: 0.04, green: 0.03, blue: 0.1),
                    Color(red: 0.02, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated orb 1 - Coral/Pink
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.3, blue: 0.4).opacity(0.35),
                            Color(red: 0.95, green: 0.3, blue: 0.4).opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: 800, height: 800)
                .blur(radius: 100)
                .offset(x: 300, y: -200)
            
            // Animated orb 2 - Blue
            Circle()
                .fill(
            RadialGradient(
                colors: [
                            Color(red: 0.2, green: 0.4, blue: 0.9).opacity(0.25),
                    Color.clear
                ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 350
            )
                )
                .frame(width: 700, height: 700)
                .blur(radius: 80)
                .offset(x: -400, y: 300)
            
            // Subtle purple accent
            Circle()
                .fill(
            RadialGradient(
                colors: [
                            Color(red: 0.5, green: 0.2, blue: 0.7).opacity(0.2),
                    Color.clear
                ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
            )
                )
                .frame(width: 500, height: 500)
                .blur(radius: 60)
                .offset(x: 100, y: 400)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Glass Header
            headerView
                .padding(.top, 50)
                .padding(.bottom, 30)
            
            // Glass Tab Bar
            glassTabBar
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
    
    // MARK: - Glass Header
    
    private var headerView: some View {
        HStack(spacing: 20) {
            // Logo with glass backing
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
            Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 40, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                                Color(red: 0.95, green: 0.35, blue: 0.45),
                                Color(red: 0.85, green: 0.25, blue: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .shadow(color: Color(red: 0.95, green: 0.3, blue: 0.4).opacity(0.3), radius: 20)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("NESCASTER")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                if let profile = profileManager.activeProfile {
                    Text("Playing as \(profile.name)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                Text("Premium NES Experience")
                        .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Profile indicator (glass)
            if let profile = profileManager.activeProfile {
                glassProfileIndicator(profile)
            }
            
            // Performance badge (glass)
            glassPerformanceBadge
        }
    }
    
    private func glassProfileIndicator(_ profile: Profile) -> some View {
        let color = ProfilePictureManager.shared.getColor(for: profile.pictureID)
        
        return Button(action: switchProfile) {
            HStack(spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 48, height: 48)
                    
                    Circle()
                        .fill(color)
                        .frame(width: 38, height: 38)
                    
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Switch")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 15, y: 5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var glassPerformanceBadge: some View {
        HStack(spacing: 10) {
            // Animated pulse
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .shadow(color: .green, radius: 6)
            
            Text("4K • 120fps")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Glass Tab Bar
    
    private var glassTabBar: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases, id: \.self) { tab in
                GlassTabButton(
                    title: tab.rawValue,
                    icon: tab == .library ? "square.grid.2x2.fill" : "gearshape.fill",
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
                .focused($focusedTab, equals: tab)
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
    }
    
    // MARK: - Actions
    
    private func switchProfile() {
        profileManager.activeProfile = nil
    }
}

// MARK: - Glass Tab Button

struct GlassTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(
                        isSelected 
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            : AnyShapeStyle(Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.white.opacity(0.3) : Color.clear,
                        lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
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
