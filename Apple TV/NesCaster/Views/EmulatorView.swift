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
    @StateObject private var emulatorCore = NESEmulatorCore()
    @StateObject private var controllerManager = GameControllerManager()
    @State private var showingMenu = false
    @State private var menuOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Metal rendering surface
            NESMetalView(emulatorCore: emulatorCore)
                .ignoresSafeArea()
            
            // Pause menu overlay
            if showingMenu {
                pauseMenuOverlay
            }
            
            // Quick info overlay (fades out)
            gameInfoOverlay
            
            // Performance overlay (debug)
            #if DEBUG
            performanceOverlay
            #endif
        }
        .onAppear {
            setupControllerInput()
            startEmulation()
        }
        .onDisappear {
            emulatorCore.pause()
        }
        .onChange(of: controllerManager.controller1State) { _, newInput in
            emulatorCore.setController1Input(newInput)
        }
        .onChange(of: controllerManager.controller2State) { _, newInput in
            emulatorCore.setController2Input(newInput)
        }
        .onExitCommand {
            // Menu button pressed - toggle pause
            withAnimation(.easeInOut(duration: 0.2)) {
                showingMenu.toggle()
                if showingMenu {
                    emulatorCore.pause()
                } else {
                    emulatorCore.resume()
                }
            }
        }
    }
    
    // MARK: - Controller Setup
    
    private func setupControllerInput() {
        // Connect controller to emulator
        controllerManager.onInputChanged = { [weak emulatorCore] controller, input in
            guard let core = emulatorCore else { return }
            if controller == 1 {
                core.setController1Input(input)
            } else {
                core.setController2Input(input)
            }
        }
        
        // Menu button shows pause menu
        controllerManager.onMenuButtonPressed = { [self] in
            withAnimation(.easeInOut(duration: 0.2)) {
                showingMenu.toggle()
                if showingMenu {
                    emulatorCore.pause()
                } else {
                    emulatorCore.resume()
                }
            }
        }
    }
    
    // MARK: - Emulation Control
    
    private func startEmulation() {
        // If we have a current game, load and start it
        if let game = appState.currentGame {
            do {
                try emulatorCore.loadROM(at: game.romPath)
                emulatorCore.start()
            } catch {
                print("❌ Failed to load ROM: \(error)")
                appState.isEmulatorRunning = false
            }
        } else {
            // Demo mode - just start with test pattern
            // The bridge generates test frames when no ROM is loaded
            emulatorCore.start()
        }
    }
    
    // MARK: - Game Info Overlay
    
    private var gameInfoOverlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(emulatorCore.romName.isEmpty ? (appState.currentGame?.title ?? "Demo Mode") : emulatorCore.romName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        Label("\(Int(emulatorCore.fps)) fps", systemImage: "speedometer")
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    menuOpacity = 0
                }
            }
        }
    }
    
    // MARK: - Performance Overlay (Debug)
    
    #if DEBUG
    private var performanceOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f fps", emulatorCore.fps))
                    Text(String(format: "%.2f ms", emulatorCore.frameTime))
                    Text("Frame: \(emulatorCore.totalFrameCount)")
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.green)
                .padding(8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .padding()
            }
        }
    }
    #endif
    
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
                    
                    Text(emulatorCore.romName.isEmpty ? "Demo" : emulatorCore.romName)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 20)
                
                // Menu options
                VStack(spacing: 12) {
                    PauseMenuButton(title: "Resume", icon: "play.fill", isPrimary: true) {
                        withAnimation {
                            showingMenu = false
                            emulatorCore.resume()
                        }
                    }
                    
                    PauseMenuButton(title: "Save State", icon: "square.and.arrow.down.fill") {
                        _ = emulatorCore.saveState(slot: 0)
                    }
                    
                    PauseMenuButton(title: "Load State", icon: "square.and.arrow.up.fill") {
                        _ = emulatorCore.loadState(slot: 0)
                    }
                    
                    PauseMenuButton(title: "Reset", icon: "arrow.counterclockwise") {
                        emulatorCore.reset()
                        withAnimation {
                            showingMenu = false
                            emulatorCore.resume()
                        }
                    }
                    
                    PauseMenuButton(title: "Quit Game", icon: "xmark.circle.fill", isDestructive: true) {
                        emulatorCore.stop()
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

// MARK: - NES Metal View

struct NESMetalView: UIViewRepresentable {
    let emulatorCore: NESEmulatorCore
    
    func makeCoordinator() -> Coordinator {
        Coordinator(emulatorCore: emulatorCore)
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal is not supported on this device")
            return mtkView
        }
        
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)
        
        // 120fps target
        mtkView.preferredFramesPerSecond = 120
        
        // Low latency settings
        mtkView.presentsWithTransaction = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        
        // Create renderer
        if let renderer = MetalRenderer(mtkView: mtkView) {
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
            
            // Connect frame buffer callback
            Task { @MainActor in
                emulatorCore.onFrameReady = { buffer in
                    renderer.updateFrame(pixelData: buffer)
                }
            }
        }
        
        print("🎮 Metal device: \(device.name)")
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // View updates handled by delegate
    }
    
    class Coordinator {
        let emulatorCore: NESEmulatorCore
        var renderer: MetalRenderer?
        
        init(emulatorCore: NESEmulatorCore) {
            self.emulatorCore = emulatorCore
        }
    }
}

#Preview {
    EmulatorView()
        .environmentObject(AppState())
}
