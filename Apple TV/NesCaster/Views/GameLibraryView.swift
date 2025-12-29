//
//  GameLibraryView.swift
//  NesCaster
//

import SwiftUI

struct GameLibraryView: View {
    
    @EnvironmentObject var appState: AppState
    @State private var selectedGame: Game?
    @State private var showingFilePicker = false
    
    // Demo games for UI testing
    private let demoGames: [Game] = [
        Game(title: "Super Mario Bros.", romPath: URL(fileURLWithPath: ""), coverArt: nil, lastPlayed: Date()),
        Game(title: "The Legend of Zelda", romPath: URL(fileURLWithPath: ""), coverArt: nil, lastPlayed: Date().addingTimeInterval(-86400)),
        Game(title: "Metroid", romPath: URL(fileURLWithPath: ""), coverArt: nil, lastPlayed: Date().addingTimeInterval(-172800)),
        Game(title: "Mega Man 2", romPath: URL(fileURLWithPath: ""), coverArt: nil, lastPlayed: nil),
        Game(title: "Castlevania", romPath: URL(fileURLWithPath: ""), coverArt: nil, lastPlayed: nil),
        Game(title: "Contra", romPath: URL(fileURLWithPath: ""), coverArt: nil, lastPlayed: nil),
    ]
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 40)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 50) {
                // Recent Games Section
                if !appState.recentGames.isEmpty || true { // Always show for demo
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
    }
    
    // MARK: - Recent Games
    
    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(title: "Continue Playing", icon: "clock.fill")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 30) {
                    ForEach(demoGames.prefix(3)) { game in
                        RecentGameCard(game: game) {
                            launchGame(game)
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
            sectionHeader(title: "All Games", icon: "square.grid.2x2.fill")
            
            LazyVGrid(columns: columns, spacing: 40) {
                ForEach(demoGames) { game in
                    GameCard(game: game) {
                        launchGame(game)
                    }
                }
            }
        }
    }
    
    // MARK: - Add Games
    
    private var addGamesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(title: "Add Games", icon: "plus.circle.fill")
            
            Button(action: { showingFilePicker = true }) {
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
                        Text("Import ROM Files")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Add .nes files from your device or network")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
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

