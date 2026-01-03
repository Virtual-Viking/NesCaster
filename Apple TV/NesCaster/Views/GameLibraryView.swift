//
//  GameLibraryView.swift
//  NesCaster
//
//  Game library with ROM management and demo mode
//

import SwiftUI

struct GameLibraryView: View {
    
    @EnvironmentObject var appState: AppState
    @State private var selectedGame: Game?
    @State private var savedGames: [Game] = []
    @State private var showingDemoAlert = false
    @State private var showingImportHelp = false
    
    // Demo games for UI testing (before ROM loading is implemented)
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
                // Demo Mode Section (for testing)
                demoModeSection
                
                // Recent Games Section
                if !appState.recentGames.isEmpty || !savedGames.isEmpty {
                    recentGamesSection
                }
                
                // All Games Section
                allGamesSection
                
                // Add Games Button
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
            Text("Launch the emulator in demo mode? This shows animated test patterns to verify the rendering pipeline is working correctly.")
        }
        .onAppear {
            loadSavedGames()
        }
    }
    
    // MARK: - Demo Mode Section
    
    private var demoModeSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(title: "Quick Start", icon: "bolt.fill")
            
            HStack(spacing: 30) {
                // Demo Mode Button
                Button(action: { showingDemoAlert = true }) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.95, green: 0.3, blue: 0.4),
                                            Color(red: 0.85, green: 0.2, blue: 0.5)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Demo Mode")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Test rendering pipeline")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial.opacity(0.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                // FPS Counter Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Ready")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.green)
                    }
                    
                    Text("Metal renderer initialized")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
    }
    
    // MARK: - Recent Games
    
    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(title: "Continue Playing", icon: "clock.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 30) {
                    // Real saved games first
                    ForEach(savedGames.prefix(3)) { game in
                        RecentGameCard(game: game) {
                            launchGame(game)
                        }
                    }
                    
                    // Then demo placeholders
                    if savedGames.isEmpty {
                        ForEach(demoGames.prefix(3)) { game in
                            RecentGameCard(game: game) {
                                showDemoGameAlert(game)
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
    
    // MARK: - All Games
    
    private var allGamesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                sectionHeader(title: "All Games", icon: "square.grid.2x2.fill")
                
                Spacer()
                
                Text("\(savedGames.count + demoGames.count) games")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            LazyVGrid(columns: columns, spacing: 40) {
                // Real games
                ForEach(savedGames) { game in
                    GameCard(game: game) {
                        launchGame(game)
                    }
                }
                
                // Demo placeholders
                ForEach(demoGames) { game in
                    GameCard(game: game, isDemo: true) {
                        showDemoGameAlert(game)
                    }
                }
            }
        }
    }
    
    // MARK: - Add Games
    
    private var addGamesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(title: "Add Games", icon: "plus.circle.fill")
            
            Button(action: { showingImportHelp = true }) {
                HStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How to Add ROMs")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Learn how to transfer .nes files to Apple TV")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .alert("How to Add ROMs", isPresented: $showingImportHelp) {
                Button("Scan for ROMs") {
                    loadSavedGames()
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text("Transfer .nes ROM files to this app's Documents folder using:\n\n• Finder (macOS) via USB\n• Third-party file managers\n• Web server upload\n\nROMs placed in the Documents folder will appear automatically.")
            }
            
            // Help text
            Text("ROMs in the app's Documents folder are detected automatically on launch.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 8)
        }
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.95, green: 0.3, blue: 0.4))
            
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
        appState.currentGame = nil // No game = demo mode
        withAnimation(.easeInOut(duration: 0.4)) {
            appState.isEmulatorRunning = true
        }
    }
    
    private func showDemoGameAlert(_ game: Game) {
        // For demo games, just launch demo mode
        showingDemoAlert = true
    }
    
    // MARK: - ROM Management
    
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
            
            print("📚 Loaded \(savedGames.count) saved games")
            
        } catch {
            print("❌ Failed to load saved games: \(error)")
        }
    }
    
    private func saveGameLibrary() {
        // TODO: Persist game metadata (play times, cover art, etc.)
    }
}

// MARK: - Recent Game Card

struct RecentGameCard: View {
    let game: Game
    let action: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Game art placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.15, blue: 0.25),
                                    Color(red: 0.1, green: 0.1, blue: 0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // NES cartridge icon
                    Image(systemName: "arcade.stick")
                        .font(.system(size: 60, weight: .thin))
                        .foregroundColor(.white.opacity(0.2))
                    
                    // Play overlay on focus
                    if isFocused {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 360, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused ? Color.white.opacity(0.5) : Color.white.opacity(0.1),
                            lineWidth: isFocused ? 3 : 1
                        )
                )
                .shadow(
                    color: isFocused ? Color(red: 0.95, green: 0.3, blue: 0.4).opacity(0.4) : .clear,
                    radius: 30
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
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game Card

struct GameCard: View {
    let game: Game
    var isDemo: Bool = false
    let action: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    // Generate consistent color from game title
    private var accentColor: Color {
        let hash = game.title.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Game art
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
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
                    
                    // Game initial
                    Text(String(game.title.prefix(1)))
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor.opacity(0.5))
                    
                    // Demo badge
                    if isDemo {
                        VStack {
                            HStack {
                                Spacer()
                                Text("DEMO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(4)
                                    .padding(8)
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
                            
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused ? accentColor : Color.white.opacity(0.1),
                            lineWidth: isFocused ? 3 : 1
                        )
                )
                .shadow(
                    color: isFocused ? accentColor.opacity(0.5) : .clear,
                    radius: 25
                )
                
                // Title
                Text(game.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    GameLibraryView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
