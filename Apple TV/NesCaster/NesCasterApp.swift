//
//  NesCasterApp.swift
//  NesCaster - Premium NES Emulator for Apple TV
//
//  High-performance NES emulation with:
//  - Sub-frame latency (< original hardware)
//  - True 120fps rendering via Metal
//  - 4K crisp scaling
//  - Modern, elegant UI
//

import SwiftUI

@main
struct NesCasterApp: App {
    
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @Published var isEmulatorRunning = false
    @Published var currentGame: Game?
    @Published var recentGames: [Game] = []
    
    // Performance settings
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

