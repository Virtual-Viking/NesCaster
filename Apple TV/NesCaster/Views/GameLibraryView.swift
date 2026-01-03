//
//  GameLibraryView.swift
//  NesCaster
//
//  Game library with Liquid Glass UI
//

import SwiftUI

struct GameLibraryView: View {
    
    @EnvironmentObject var appState: AppState
    @State private var selectedGame: Game?
    @State private var savedGames: [Game] = []
    @State private var showingDemoAlert = false
    @State private var showingImportHelp = false
    
    // Demo games for UI testing
    private let demoGames: [Game] = [
        Game(title: "Super Mario Bros.", romPath: URL(fileURLWithPath: "/demo/smb.nes"), coverArt: nil, lastPlayed: Date()),
        Game(title: "The Legend of Zelda", romPath: URL(fileURLWithPath: "/demo/zelda.nes"), coverArt: nil, lastPlayed: Date().addingTimeInterval(-86400)),
        Game(title: "Metroid", romPath: URL(fileURLWithPath: "/demo/metroid.nes"), coverArt: nil, lastPlayed: Date().addingTimeInterval(-172800)),
        Game(title: "Mega Man 2", romPath: URL(fileURLWithPath: "/demo/megaman2.nes"), coverArt: nil, lastPlayed: nil),
        Game(title: "Castlevania", romPath: URL(fileURLWithPath: "/demo/castlevania.nes"), coverArt: nil, lastPlayed: nil),
        Game(title: "Contra", romPath: URL(fileURLWithPath: "/demo/contra.nes"), coverArt: nil, lastPlayed: nil),
    ]
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 40)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 50) {
                // Quick Start Section
                quickStartSection
                
                // Recent Games
                if !appState.recentGames.isEmpty || !savedGames.isEmpty {
                    recentGamesSection
                }
                
                // All Games
                allGamesSection
                
                // Add Games
                addGamesSection
            }
            .padding(.bottom, 80)
        }
        .scrollClipDisabled()
        .alert("Demo Mode", isPresented: $showingDemoAlert) {
            Button("Launch Demo") {
                launchDemoMode()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Launch the emulator in demo mode? This shows animated test patterns to verify rendering.")
        }
        .onAppear {
            loadSavedGames()
        }
    }
    
    // MARK: - Quick Start Section
    
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            glassHeader(title: "Quick Start", icon: "bolt.fill")
            
            HStack(spacing: 30) {
                // Demo Mode Button (Glass)
                Button(action: { showingDemoAlert = true }) {
                    HStack(spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.95, green: 0.35, blue: 0.45),
                                            Color(red: 0.85, green: 0.25, blue: 0.55)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color(red: 0.95, green: 0.3, blue: 0.4).opacity(0.4), radius: 15)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Demo Mode")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Test rendering pipeline")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.25), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 15, y: 8)
                    )
                }
                .buttonStyle(GlassButtonStyle())
                
                // Status indicator
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .shadow(color: .green, radius: 5)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.green)
                        Text("Metal renderer active")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.5))
                )
            }
        }
    }
    
    // MARK: - Recent Games Section
    
    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            glassHeader(title: "Continue Playing", icon: "clock.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 30) {
                    ForEach(savedGames.isEmpty ? Array(demoGames.prefix(3)) : Array(savedGames.prefix(3))) { game in
                        GlassRecentGameCard(game: game) {
                            if savedGames.isEmpty {
                                showingDemoAlert = true
                            } else {
                                launchGame(game)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
        }
    }
    
    // MARK: - All Games Section
    
    private var allGamesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                glassHeader(title: "All Games", icon: "square.grid.2x2.fill")
                
                Spacer()
                
                Text("\(savedGames.count + demoGames.count) games")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial.opacity(0.5))
                    )
            }
            
            LazyVGrid(columns: columns, spacing: 40) {
                ForEach(savedGames) { game in
                    GlassGameCard(game: game) {
                        launchGame(game)
                    }
                }
                
                ForEach(demoGames) { game in
                    GlassGameCard(game: game, isDemo: true) {
                        showingDemoAlert = true
                    }
                }
            }
        }
    }
    
    // MARK: - Add Games Section
    
    private var addGamesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            glassHeader(title: "Add Games", icon: "plus.circle.fill")
            
            Button(action: { showingImportHelp = true }) {
                HStack(spacing: 22) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white.opacity(0.7), .white.opacity(0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How to Add ROMs")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Transfer .nes files to Apple TV")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.trailing, 8)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.2), .white.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                )
            }
            .buttonStyle(GlassButtonStyle())
            .alert("How to Add ROMs", isPresented: $showingImportHelp) {
                Button("Scan for ROMs") { loadSavedGames() }
                Button("OK", role: .cancel) { }
            } message: {
                Text("Transfer .nes files to this app's Documents folder using Finder (USB), web upload, or third-party file managers.")
            }
            
            Text("ROMs in Documents folder are detected automatically.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 4)
        }
    }
    
    // MARK: - Helpers
    
    private func glassHeader(title: String, icon: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.45))
            }
            
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func launchGame(_ game: Game) {
        appState.currentGame = game
        withAnimation(.easeInOut(duration: 0.4)) {
            appState.isEmulatorRunning = true
        }
    }
    
    private func launchDemoMode() {
        appState.currentGame = nil
        withAnimation(.easeInOut(duration: 0.4)) {
            appState.isEmulatorRunning = true
        }
    }
    
    private func loadSavedGames() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            savedGames = files
                .filter { $0.pathExtension.lowercased() == "nes" }
                .map { url in
                    Game(
                        title: url.deletingPathExtension().lastPathComponent,
                        romPath: url,
                        coverArt: nil,
                        lastPlayed: nil
                    )
                }
                .sorted { $0.title < $1.title }
        } catch {
            print("❌ Failed to load saved games: \(error)")
        }
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Glass Recent Game Card

struct GlassRecentGameCard: View {
    let game: Game
    let action: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    private var accentColor: Color {
        let hash = game.title.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 18) {
                // Game art with glass frame
                ZStack {
                    // Glass background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accentColor.opacity(0.3),
                                            accentColor.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    
                    // Icon
                    Image(systemName: "arcade.stick")
                        .font(.system(size: 56, weight: .thin))
                        .foregroundColor(.white.opacity(0.25))
                    
                    // Play overlay
                    if isFocused {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 360, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isFocused 
                                ? LinearGradient(colors: [accentColor.opacity(0.8), accentColor.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isFocused ? 3 : 1
                        )
                )
                .shadow(
                    color: isFocused ? accentColor.opacity(0.4) : .clear,
                    radius: 25
                )
                
                // Game info
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if let lastPlayed = game.lastPlayed {
                        Text(lastPlayed.formatted(.relative(presentation: .named)))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 4)
            }
            .scaleEffect(isFocused ? 1.03 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Game Card

struct GlassGameCard: View {
    let game: Game
    var isDemo: Bool = false
    let action: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    private var accentColor: Color {
        let hash = game.title.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.55, brightness: 0.75)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Glass card art
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accentColor.opacity(0.35),
                                            accentColor.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    
                    // Game initial
                    Text(String(game.title.prefix(1)))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor.opacity(0.6))
                    
                    // Demo badge
                    if isDemo {
                        VStack {
                            HStack {
                                Spacer()
                                Text("DEMO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                    )
                                    .padding(10)
                            }
                            Spacer()
                        }
                    }
                    
                    // Play overlay
                    if isFocused {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isFocused
                                ? LinearGradient(colors: [accentColor.opacity(0.8), accentColor.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isFocused ? 3 : 1
                        )
                )
                .shadow(
                    color: isFocused ? accentColor.opacity(0.5) : .clear,
                    radius: 20
                )
                
                // Title
                Text(game.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GameLibraryView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
