//
//  ControllerMappingView.swift
//  NesCaster
//
//  Liquid Glass UI for controller button mapping
//

import SwiftUI
import GameController

struct ControllerMappingView: View {
    
    @ObservedObject var mappingManager: ControllerMappingManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Glass background
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.03, blue: 0.08),
                        Color(red: 0.06, green: 0.04, blue: 0.12),
                        Color(red: 0.03, green: 0.03, blue: 0.07)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        // Connected Controllers
                        connectedControllersSection
                        
                        // Button Mappings
                        buttonMappingsSection
                        
                        // Actions
                        actionsSection
                    }
                    .padding(40)
                }
                
                // Remapping overlay
                if mappingManager.isRemappingMode {
                    remappingOverlay
                }
            }
            .navigationTitle("Controller Mapping")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset Mapping", isPresented: $showingResetConfirmation) {
                Button("Reset", role: .destructive) {
                    mappingManager.resetToDefaults()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Reset all button mappings to defaults?")
            }
        }
    }
    
    // MARK: - Connected Controllers Section
    
    private var connectedControllersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            glassHeader(title: "Controllers", icon: "gamecontroller.fill", color: .green)
            
            if mappingManager.connectedControllers.isEmpty {
                // No controllers
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .frame(width: 52, height: 52)
                        
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No Controllers Connected")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Connect a controller via Bluetooth in Settings")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    
                    Spacer()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial.opacity(0.6))
                )
            } else {
                // List connected controllers
                ForEach(mappingManager.connectedControllers, id: \.vendorName) { controller in
                    ControllerRow(
                        controller: controller,
                        isPaired: mappingManager.isPaired(controller),
                        onPair: { mappingManager.pairController(controller) },
                        onUnpair: { mappingManager.unpairController() }
                    )
                }
            }
            
            // Paired controller info
            if let name = mappingManager.currentMapping.controllerName {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Paired: \(name)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.15))
                )
            }
        }
    }
    
    // MARK: - Button Mappings Section
    
    private var buttonMappingsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            glassHeader(title: "Button Mapping", icon: "slider.horizontal.3", color: Color(red: 0.95, green: 0.35, blue: 0.45))
            
            // Group by category
            ForEach(RemappableButton.ButtonCategory.allCases, id: \.self) { category in
                VStack(alignment: .leading, spacing: 12) {
                    Text(category.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.leading, 4)
                    
                    VStack(spacing: 8) {
                        ForEach(RemappableButton.allCases.filter { $0.category == category }) { button in
                            ButtonMappingRow(
                                button: button,
                                currentMapping: currentMappingFor(button),
                                displayName: mappingManager.displayName(for: currentMappingFor(button)),
                                symbolName: mappingManager.symbolName(for: currentMappingFor(button)),
                                onRemap: { mappingManager.startRemapping(button) }
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        HStack(spacing: 20) {
            Button(action: { showingResetConfirmation = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to Defaults")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    // MARK: - Remapping Overlay
    
    private var remappingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated controller icon
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.35, blue: 0.45), Color(red: 0.85, green: 0.25, blue: 0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: Color(red: 0.95, green: 0.3, blue: 0.4).opacity(0.4), radius: 25)
                
                VStack(spacing: 12) {
                    if let button = mappingManager.buttonBeingRemapped {
                        Text("Press button for \(button.rawValue)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Press any button on your controller")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Button(action: { mappingManager.cancelRemapping() }) {
                    Text("Cancel")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(50)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 40)
            )
        }
    }
    
    // MARK: - Helpers
    
    private func glassHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color.opacity(0.2))
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            .shadow(color: color.opacity(0.3), radius: 10)
            
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private func currentMappingFor(_ button: RemappableButton) -> String {
        switch button {
        case .a: return mappingManager.currentMapping.buttonA
        case .b: return mappingManager.currentMapping.buttonB
        case .start: return mappingManager.currentMapping.buttonStart
        case .select: return mappingManager.currentMapping.buttonSelect
        case .up: return mappingManager.currentMapping.dpadUp
        case .down: return mappingManager.currentMapping.dpadDown
        case .left: return mappingManager.currentMapping.dpadLeft
        case .right: return mappingManager.currentMapping.dpadRight
        case .quickSave: return mappingManager.currentMapping.quickSave
        case .quickLoad: return mappingManager.currentMapping.quickLoad
        case .turboA: return mappingManager.currentMapping.turboA ?? "Not Set"
        case .turboB: return mappingManager.currentMapping.turboB ?? "Not Set"
        }
    }
}

// MARK: - Controller Row

struct ControllerRow: View {
    let controller: GCController
    let isPaired: Bool
    let onPair: () -> Void
    let onUnpair: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        HStack(spacing: 16) {
            // Controller icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isPaired ? .green : .white.opacity(0.7))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(controller.vendorName ?? "Controller")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(controller.productCategory)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Pair/Unpair button
            Button(action: { isPaired ? onUnpair() : onPair() }) {
                Text(isPaired ? "Unpair" : "Pair")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isPaired ? .red : .green)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(isPaired ? Color.red.opacity(0.5) : Color.green.opacity(0.5), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            
            // Status
            Circle()
                .fill(isPaired ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 10, height: 10)
                .shadow(color: isPaired ? .green : .clear, radius: 4)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isFocused ? Color.green.opacity(0.6) : Color.white.opacity(0.1),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isFocused)
    }
}

// MARK: - Button Mapping Row

struct ButtonMappingRow: View {
    let button: RemappableButton
    let currentMapping: String
    let displayName: String
    let symbolName: String
    let onRemap: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        Button(action: onRemap) {
            HStack(spacing: 16) {
                // NES button icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.95, green: 0.35, blue: 0.45).opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: button.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.45))
                }
                
                // Button name
                Text(button.rawValue)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Current mapping
                HStack(spacing: 8) {
                    Image(systemName: symbolName)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.6))
                )
                
                // Edit indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isFocused ? Color(red: 0.95, green: 0.35, blue: 0.45).opacity(0.6) : Color.white.opacity(0.08),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ControllerMappingView(mappingManager: ControllerMappingManager(profileID: UUID()))
        .preferredColorScheme(.dark)
}

