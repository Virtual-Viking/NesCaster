//
//  GameControllerManager.swift
//  NesCaster
//
//  Handles game controller input for Apple TV
//  Supports: MFi controllers, Siri Remote, PlayStation, Xbox controllers
//

import GameController
import Combine

// MARK: - Controller Manager

@MainActor
class GameControllerManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var connectedControllers: [GCController] = []
    @Published private(set) var primaryController: GCController?
    @Published private(set) var isUsingRemote: Bool = false
    
    /// Current input state for NES controller 1
    @Published private(set) var controller1State: NESInput = []
    
    /// Current input state for NES controller 2
    @Published private(set) var controller2State: NESInput = []
    
    // MARK: - Callbacks
    
    /// Called when input state changes
    var onInputChanged: ((_ controller: Int, _ input: NESInput) -> Void)?
    
    /// Called when a button is pressed (for UI navigation)
    var onMenuButtonPressed: (() -> Void)?
    
    // MARK: - Private
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupControllerNotifications()
        discoverControllers()
    }
    
    // MARK: - Controller Discovery
    
    private func setupControllerNotifications() {
        // Controller connected
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let controller = notification.object as? GCController {
                    self?.controllerConnected(controller)
                }
            }
            .store(in: &cancellables)
        
        // Controller disconnected
        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let controller = notification.object as? GCController {
                    self?.controllerDisconnected(controller)
                }
            }
            .store(in: &cancellables)
    }
    
    private func discoverControllers() {
        GCController.startWirelessControllerDiscovery { [weak self] in
            print("🎮 Controller discovery completed")
            self?.updateConnectedControllers()
        }
    }
    
    private func updateConnectedControllers() {
        connectedControllers = GCController.controllers()
        primaryController = connectedControllers.first
        
        // Check if using Siri Remote
        isUsingRemote = connectedControllers.contains { $0.microGamepad != nil }
        
        print("🎮 Connected controllers: \(connectedControllers.count)")
        connectedControllers.forEach { controller in
            print("   - \(controller.vendorName ?? "Unknown")")
        }
    }
    
    // MARK: - Controller Events
    
    private func controllerConnected(_ controller: GCController) {
        print("🎮 Controller connected: \(controller.vendorName ?? "Unknown")")
        
        updateConnectedControllers()
        configureController(controller)
        
        // Assign to first available player
        if controller.playerIndex == .indexUnset {
            controller.playerIndex = connectedControllers.count <= 1 ? .index1 : .index2
        }
    }
    
    private func controllerDisconnected(_ controller: GCController) {
        print("🎮 Controller disconnected: \(controller.vendorName ?? "Unknown")")
        updateConnectedControllers()
    }
    
    // MARK: - Controller Configuration
    
    private func configureController(_ controller: GCController) {
        // Configure extended gamepad (MFi, PlayStation, Xbox)
        if let gamepad = controller.extendedGamepad {
            configureExtendedGamepad(gamepad, playerIndex: controller.playerIndex)
        }
        // Configure micro gamepad (Siri Remote)
        else if let microGamepad = controller.microGamepad {
            configureMicroGamepad(microGamepad)
        }
    }
    
    private func configureExtendedGamepad(_ gamepad: GCExtendedGamepad, playerIndex: GCControllerPlayerIndex) {
        let controllerIndex = playerIndex == .index1 ? 1 : 2
        
        // D-Pad
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.updateDPad(x: xValue, y: yValue, controller: controllerIndex)
        }
        
        // Left Thumbstick (alternative to D-Pad)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.updateDPad(x: xValue, y: yValue, controller: controllerIndex)
        }
        
        // A Button (NES A)
        gamepad.buttonA.valueChangedHandler = { [weak self] _, _, pressed in
            self?.updateButton(.a, pressed: pressed, controller: controllerIndex)
        }
        
        // B Button / X Button (NES B)
        gamepad.buttonB.valueChangedHandler = { [weak self] _, _, pressed in
            self?.updateButton(.b, pressed: pressed, controller: controllerIndex)
        }
        gamepad.buttonX.valueChangedHandler = { [weak self] _, _, pressed in
            self?.updateButton(.b, pressed: pressed, controller: controllerIndex)
        }
        
        // Y Button (Alternative NES A - turbo)
        gamepad.buttonY.valueChangedHandler = { [weak self] _, _, pressed in
            self?.updateButton(.a, pressed: pressed, controller: controllerIndex)
        }
        
        // Shoulder buttons for Select/Start
        gamepad.leftShoulder.valueChangedHandler = { [weak self] _, _, pressed in
            self?.updateButton(.select, pressed: pressed, controller: controllerIndex)
        }
        
        gamepad.rightShoulder.valueChangedHandler = { [weak self] _, _, pressed in
            self?.updateButton(.start, pressed: pressed, controller: controllerIndex)
        }
        
        // Menu button
        gamepad.buttonMenu.valueChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.onMenuButtonPressed?()
            }
        }
    }
    
    private func configureMicroGamepad(_ microGamepad: GCMicroGamepad) {
        microGamepad.reportsAbsoluteDpadValues = true
        microGamepad.allowsRotation = false
        
        // Touch surface as D-Pad
        microGamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.updateDPad(x: xValue, y: yValue, controller: 1)
        }
        
        // Play/Pause button (NES Start)
        microGamepad.buttonA.valueChangedHandler = { [weak self] _, _, pressed in
            self?.updateButton(.a, pressed: pressed, controller: 1)
        }
        
        // Select button (NES Select)
        microGamepad.buttonX.valueChangedHandler = { [weak self] _, _, pressed in
            self?.updateButton(.b, pressed: pressed, controller: 1)
        }
        
        // Menu button
        microGamepad.buttonMenu.valueChangedHandler = { [weak self] _, _, pressed in
            if pressed {
                self?.onMenuButtonPressed?()
            }
        }
    }
    
    // MARK: - Input State Updates
    
    private func updateDPad(x: Float, y: Float, controller: Int) {
        var input = controller == 1 ? controller1State : controller2State
        
        // Threshold for digital input
        let threshold: Float = 0.5
        
        // Horizontal
        if x < -threshold {
            input.insert(.left)
            input.remove(.right)
        } else if x > threshold {
            input.insert(.right)
            input.remove(.left)
        } else {
            input.remove([.left, .right])
        }
        
        // Vertical (inverted for NES coordinates)
        if y > threshold {
            input.insert(.up)
            input.remove(.down)
        } else if y < -threshold {
            input.insert(.down)
            input.remove(.up)
        } else {
            input.remove([.up, .down])
        }
        
        updateControllerState(input, controller: controller)
    }
    
    private func updateButton(_ button: NESInput, pressed: Bool, controller: Int) {
        var input = controller == 1 ? controller1State : controller2State
        
        if pressed {
            input.insert(button)
        } else {
            input.remove(button)
        }
        
        updateControllerState(input, controller: controller)
    }
    
    private func updateControllerState(_ input: NESInput, controller: Int) {
        if controller == 1 {
            controller1State = input
        } else {
            controller2State = input
        }
        
        onInputChanged?(controller, input)
    }
    
    // MARK: - Public Methods
    
    /// Manually poll controller state (for run-ahead)
    func pollInput() -> (controller1: NESInput, controller2: NESInput) {
        return (controller1State, controller2State)
    }
    
    /// Enable/disable controller for player
    func setControllerEnabled(_ enabled: Bool, for playerIndex: Int) {
        guard let controller = connectedControllers.first(where: {
            $0.playerIndex.rawValue == playerIndex - 1
        }) else { return }
        
        if enabled {
            configureController(controller)
        } else {
            // Clear handlers
            controller.extendedGamepad?.dpad.valueChangedHandler = nil
            controller.extendedGamepad?.buttonA.valueChangedHandler = nil
            // ... etc
        }
    }
    
    /// Set controller LED color (for supported controllers)
    func setControllerLightColor(_ color: GCColor, for playerIndex: Int) {
        guard let controller = connectedControllers.first(where: {
            $0.playerIndex.rawValue == playerIndex - 1
        }) else { return }
        
        controller.light?.color = color
    }
    
    /// Trigger haptic feedback
    func triggerHaptic(intensity: Float = 0.5, duration: Float = 0.1) {
        guard let controller = primaryController,
              let haptics = controller.haptics else { return }
        
        // Create haptic pattern
        if let engine = haptics.createEngine(withLocality: .default) {
            // Configure and play haptic
            // This requires additional setup for CHHapticEngine
        }
    }
}

// MARK: - Input Debug

extension NESInput: CustomStringConvertible {
    var description: String {
        var buttons: [String] = []
        if contains(.a) { buttons.append("A") }
        if contains(.b) { buttons.append("B") }
        if contains(.select) { buttons.append("Select") }
        if contains(.start) { buttons.append("Start") }
        if contains(.up) { buttons.append("↑") }
        if contains(.down) { buttons.append("↓") }
        if contains(.left) { buttons.append("←") }
        if contains(.right) { buttons.append("→") }
        return buttons.isEmpty ? "None" : buttons.joined(separator: " ")
    }
}

