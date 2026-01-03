//
//  NesCasterApp.swift
//  NesCaster - Premium NES Emulator for Apple TV
//
//  High-performance NES emulation with:
//  - Sub-frame latency (< original hardware)
//  - True 120fps rendering via Metal
//  - 4K crisp scaling
//  - Multi-profile support
//  - Smart save states with history
//

import SwiftUI

@main
struct NesCasterApp: App {
    
    @StateObject private var appState = AppState()
    @StateObject private var profileManager = ProfileManager()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(profileManager)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root View (Handles profile selection flow)

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        Group {
            if profileManager.isLoading {
                // Loading screen
                loadingView
            } else if profileManager.activeProfile == nil {
                // Show profile selection
                ProfileSelectionView(profileManager: profileManager) { profile in
                    profileManager.switchToProfile(profile)
                }
            } else {
                // Main app with active profile
                ContentView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: profileManager.activeProfile?.id)
    }
    
    private var loadingView: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.06).ignoresSafeArea()
            
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Loading...")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @Published var isEmulatorRunning = false
    @Published var currentGame: Game?
    @Published var recentGames: [Game] = []
    
    // Global settings (not per-profile)
    @Published var targetFrameRate: FrameRate = .fps120
    @Published var scalingMode: ScalingMode = .integerScale
    @Published var audioLatencyMode: AudioLatency = .low
    
    enum FrameRate: String, CaseIterable {
        case fps60 = "60 Hz"
        case fps120 = "120 Hz"
    }
    
    enum ScalingMode: String, CaseIterable {
        case integerScale = "Pixel Perfect"
        case aspectFill = "Aspect Fill"
        case stretch = "Stretch"
    }
    
    enum AudioLatency: String, CaseIterable {
        case low = "Low (Gaming)"
        case normal = "Normal"
    }
}

// MARK: - Game Model

struct Game: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let romPath: URL
    let coverArt: String?
    let lastPlayed: Date?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Game, rhs: Game) -> Bool {
        lhs.id == rhs.id
    }
}
