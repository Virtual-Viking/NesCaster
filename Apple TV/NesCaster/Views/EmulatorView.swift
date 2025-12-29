//
//  EmulatorView.swift
//  NesCaster
//
//  The main emulation view - displays NES output via Metal
//  Targets: 4K resolution, 120fps, sub-frame latency
//

import SwiftUI
import MetalKit

struct EmulatorView: View {
    
    @EnvironmentObject var appState: AppState
    @State private var showingMenu = false
    @State private var menuOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Metal rendering surface
            MetalView()
                .ignoresSafeArea()
            
            // Pause menu overlay
            if showingMenu {
                pauseMenuOverlay
            }
            
            // Quick info overlay (fades out)
            gameInfoOverlay
        }
        .onExitCommand {
            // Menu button pressed
            withAnimation(.easeInOut(duration: 0.2)) {
                showingMenu.toggle()
            }
        }
    }
    
    // MARK: - Game Info Overlay
    
    private var gameInfoOverlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.currentGame?.title ?? "Unknown Game")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        Label("120 fps", systemImage: "speedometer")
                        Label("4K", systemImage: "4k.tv.fill")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial.opacity(0.8))
                )
                
                Spacer()
            }
            .padding(40)
            
            Spacer()
        }
        .opacity(menuOpacity)
        .onAppear {
            // Show briefly then fade out
            withAnimation(.easeIn(duration: 0.3)) {
                menuOpacity = 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.5)) {
                    menuOpacity = 0
                }
            }
        }
    }
    
    // MARK: - Pause Menu
    
    private var pauseMenuOverlay: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Menu content
            VStack(spacing: 30) {
                // Game title
                VStack(spacing: 8) {
                    Text("PAUSED")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(4)
                    
                    Text(appState.currentGame?.title ?? "")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 20)
                
                // Menu options
                VStack(spacing: 12) {
                    PauseMenuButton(title: "Resume", icon: "play.fill", isPrimary: true) {
                        withAnimation { showingMenu = false }
                    }
                    
                    PauseMenuButton(title: "Save State", icon: "square.and.arrow.down.fill") {
                        // Save state action
                    }
                    
                    PauseMenuButton(title: "Load State", icon: "square.and.arrow.up.fill") {
                        // Load state action
                    }
                    
                    PauseMenuButton(title: "Settings", icon: "gearshape.fill") {
                        // Show settings
                    }
                    
                    PauseMenuButton(title: "Quit Game", icon: "xmark.circle.fill", isDestructive: true) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.isEmulatorRunning = false
                            appState.currentGame = nil
                        }
                    }
                }
            }
            .padding(50)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .transition(.opacity)
    }
}

// MARK: - Pause Menu Button

struct PauseMenuButton: View {
    let title: String
    let icon: String
    var isPrimary: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    private var foregroundColor: Color {
        if isDestructive { return .red }
        if isPrimary { return .white }
        return .white.opacity(0.8)
    }
    
    private var backgroundColor: Color {
        if isFocused {
            if isDestructive { return .red.opacity(0.3) }
            if isPrimary { return Color(red: 0.95, green: 0.3, blue: 0.4).opacity(0.4) }
            return .white.opacity(0.15)
        }
        return .clear
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                
                Spacer()
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isFocused ? foregroundColor.opacity(0.5) : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.25), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Metal View (Placeholder)

struct MetalView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        // 120fps target
        mtkView.preferredFramesPerSecond = 120
        
        // Low latency settings
        mtkView.presentsWithTransaction = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        // Enable high performance mode
        if let device = mtkView.device {
            print("🎮 Metal device: \(device.name)")
            print("🎮 Supports 120fps: \(device.supportsFamily(.apple7))")
        }
        
        // TODO: Connect to MetalRenderer and NES core
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update view if needed
    }
}

#Preview {
    EmulatorView()
        .environmentObject(AppState())
}

