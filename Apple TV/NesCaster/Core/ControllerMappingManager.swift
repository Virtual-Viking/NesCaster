//
//  ControllerMappingManager.swift
//  NesCaster
//
//  Manages controller pairing and button remapping per profile
//

import Foundation
import GameController
import Combine

@MainActor
class ControllerMappingManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var connectedControllers: [GCController] = []
    @Published private(set) var pairedControllerID: String?
    @Published var currentMapping: ControllerMapping
    @Published var isRemappingMode = false
    @Published var buttonBeingRemapped: RemappableButton?
    
    // MARK: - Private Properties
    
    private var profileID: UUID
    private let fileManager = FileManager.default
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    static let shared = ControllerMappingManager(profileID: UUID())
    
    // MARK: - Initialization
    
    init(profileID: UUID) {
        self.profileID = profileID
        self.currentMapping = ControllerMapping(profileID: profileID)
        
        loadMapping()
        setupControllerNotifications()
        updateConnectedControllers()
    }
    
    // MARK: - Profile Setup
    
    func setProfile(_ profileID: UUID) {
        self.profileID = profileID
        self.currentMapping = ControllerMapping(profileID: profileID)
        loadMapping()
    }
    
    // MARK: - Controller Notifications
    
    private func setupControllerNotifications() {
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .sink { [weak self] notification in
                if let controller = notification.object as? GCController {
                    self?.handleControllerConnected(controller)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .sink { [weak self] notification in
                if let controller = notification.object as? GCController {
                    self?.handleControllerDisconnected(controller)
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateConnectedControllers() {
        connectedControllers = GCController.controllers()
    }
    
    private func handleControllerConnected(_ controller: GCController) {
        updateConnectedControllers()
        
        let controllerID = getControllerID(controller)
        
        // Check if this controller is paired to this profile
        if currentMapping.controllerID == controllerID {
            print("🎮 Paired controller reconnected: \(controller.vendorName ?? "Unknown")")
        }
    }
    
    private func handleControllerDisconnected(_ controller: GCController) {
        updateConnectedControllers()
    }
    
    // MARK: - Controller Identification
    
    func getControllerID(_ controller: GCController) -> String {
        // Create a unique ID from vendor name and product category
        let vendor = controller.vendorName ?? "Unknown"
        let category = controller.productCategory
        return "\(vendor)_\(category)"
    }
    
    func getControllerName(_ controller: GCController) -> String {
        if let vendor = controller.vendorName {
            return vendor
        }
        return controller.productCategory
    }
    
    // MARK: - Pairing
    
    /// Pair a controller to the current profile
    func pairController(_ controller: GCController) {
        let controllerID = getControllerID(controller)
        currentMapping.controllerID = controllerID
        currentMapping.controllerName = getControllerName(controller)
        pairedControllerID = controllerID
        
        saveMapping()
        print("🎮 Paired controller: \(currentMapping.controllerName ?? "Unknown") to profile")
    }
    
    /// Unpair the current controller
    func unpairController() {
        currentMapping.controllerID = nil
        currentMapping.controllerName = nil
        pairedControllerID = nil
        
        saveMapping()
        print("🎮 Controller unpaired from profile")
    }
    
    /// Check if a controller is paired to this profile
    func isPaired(_ controller: GCController) -> Bool {
        guard let pairedID = currentMapping.controllerID else { return false }
        return getControllerID(controller) == pairedID
    }
    
    // MARK: - Button Remapping
    
    /// Start remapping a button
    func startRemapping(_ button: RemappableButton) {
        isRemappingMode = true
        buttonBeingRemapped = button
        
        // Listen for button presses on all connected controllers
        for controller in connectedControllers {
            setupRemapListeners(for: controller)
        }
    }
    
    /// Cancel remapping mode
    func cancelRemapping() {
        isRemappingMode = false
        buttonBeingRemapped = nil
        removeRemapListeners()
    }
    
    /// Apply a button remap
    func applyRemap(_ physicalButton: String) {
        guard let button = buttonBeingRemapped else { return }
        
        switch button {
        case .a: currentMapping.buttonA = physicalButton
        case .b: currentMapping.buttonB = physicalButton
        case .start: currentMapping.buttonStart = physicalButton
        case .select: currentMapping.buttonSelect = physicalButton
        case .up: currentMapping.dpadUp = physicalButton
        case .down: currentMapping.dpadDown = physicalButton
        case .left: currentMapping.dpadLeft = physicalButton
        case .right: currentMapping.dpadRight = physicalButton
        case .quickSave: currentMapping.quickSave = physicalButton
        case .quickLoad: currentMapping.quickLoad = physicalButton
        case .turboA: currentMapping.turboA = physicalButton
        case .turboB: currentMapping.turboB = physicalButton
        }
        
        saveMapping()
        cancelRemapping()
    }
    
    /// Reset to default mapping
    func resetToDefaults() {
        let profileID = currentMapping.profileID
        let controllerID = currentMapping.controllerID
        let controllerName = currentMapping.controllerName
        
        currentMapping = ControllerMapping(profileID: profileID)
        currentMapping.controllerID = controllerID
        currentMapping.controllerName = controllerName
        
        saveMapping()
    }
    
    // MARK: - Remap Listeners
    
    private func setupRemapListeners(for controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        // Face buttons
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("buttonA") }
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("buttonB") }
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("buttonX") }
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("buttonY") }
        }
        
        // Shoulders
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("leftShoulder") }
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("rightShoulder") }
        }
        
        // Triggers
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("leftTrigger") }
        }
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("rightTrigger") }
        }
        
        // D-Pad
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("dpadUp") }
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("dpadDown") }
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("dpadLeft") }
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("dpadRight") }
        }
        
        // Menu/Options
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("buttonMenu") }
        }
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.applyRemap("buttonOptions") }
        }
    }
    
    private func removeRemapListeners() {
        for controller in connectedControllers {
            guard let gamepad = controller.extendedGamepad else { continue }
            
            gamepad.buttonA.pressedChangedHandler = nil
            gamepad.buttonB.pressedChangedHandler = nil
            gamepad.buttonX.pressedChangedHandler = nil
            gamepad.buttonY.pressedChangedHandler = nil
            gamepad.leftShoulder.pressedChangedHandler = nil
            gamepad.rightShoulder.pressedChangedHandler = nil
            gamepad.leftTrigger.pressedChangedHandler = nil
            gamepad.rightTrigger.pressedChangedHandler = nil
            gamepad.dpad.up.pressedChangedHandler = nil
            gamepad.dpad.down.pressedChangedHandler = nil
            gamepad.dpad.left.pressedChangedHandler = nil
            gamepad.dpad.right.pressedChangedHandler = nil
            gamepad.buttonMenu.pressedChangedHandler = nil
            gamepad.buttonOptions?.pressedChangedHandler = nil
        }
    }
    
    // MARK: - Persistence
    
    private var mappingPath: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let profileDir = documentsURL.appendingPathComponent("Profiles/\(profileID.uuidString)")
        try? fileManager.createDirectory(at: profileDir, withIntermediateDirectories: true)
        return profileDir.appendingPathComponent("controller.json")
    }
    
    func saveMapping() {
        do {
            let data = try JSONEncoder().encode(currentMapping)
            try data.write(to: mappingPath)
            print("💾 Controller mapping saved")
        } catch {
            print("❌ Failed to save controller mapping: \(error)")
        }
    }
    
    func loadMapping() {
        guard let data = try? Data(contentsOf: mappingPath),
              let mapping = try? JSONDecoder().decode(ControllerMapping.self, from: data) else {
            // Use default mapping
            currentMapping = ControllerMapping(profileID: profileID)
            return
        }
        
        currentMapping = mapping
        pairedControllerID = mapping.controllerID
        print("📂 Controller mapping loaded")
    }
    
    // MARK: - Button Display Names
    
    func displayName(for physicalButton: String) -> String {
        switch physicalButton {
        case "buttonA": return "A Button"
        case "buttonB": return "B Button"
        case "buttonX": return "X Button"
        case "buttonY": return "Y Button"
        case "leftShoulder": return "L1 / LB"
        case "rightShoulder": return "R1 / RB"
        case "leftTrigger": return "L2 / LT"
        case "rightTrigger": return "R2 / RT"
        case "dpadUp": return "D-Pad Up"
        case "dpadDown": return "D-Pad Down"
        case "dpadLeft": return "D-Pad Left"
        case "dpadRight": return "D-Pad Right"
        case "buttonMenu": return "Menu"
        case "buttonOptions": return "Options"
        default: return physicalButton
        }
    }
    
    func symbolName(for physicalButton: String) -> String {
        switch physicalButton {
        case "buttonA": return "a.circle.fill"
        case "buttonB": return "b.circle.fill"
        case "buttonX": return "x.circle.fill"
        case "buttonY": return "y.circle.fill"
        case "leftShoulder": return "l1.rectangle.roundedbottom.fill"
        case "rightShoulder": return "r1.rectangle.roundedbottom.fill"
        case "leftTrigger": return "l2.rectangle.roundedtop.fill"
        case "rightTrigger": return "r2.rectangle.roundedtop.fill"
        case "dpadUp": return "arrowtriangle.up.fill"
        case "dpadDown": return "arrowtriangle.down.fill"
        case "dpadLeft": return "arrowtriangle.left.fill"
        case "dpadRight": return "arrowtriangle.right.fill"
        case "buttonMenu": return "line.3.horizontal"
        case "buttonOptions": return "ellipsis"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Remappable Buttons

enum RemappableButton: String, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"
    case start = "Start"
    case select = "Select"
    case up = "Up"
    case down = "Down"
    case left = "Left"
    case right = "Right"
    case quickSave = "Quick Save"
    case quickLoad = "Quick Load"
    case turboA = "Turbo A"
    case turboB = "Turbo B"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .a: return "a.circle"
        case .b: return "b.circle"
        case .start: return "play.fill"
        case .select: return "square.fill"
        case .up: return "arrowtriangle.up"
        case .down: return "arrowtriangle.down"
        case .left: return "arrowtriangle.left"
        case .right: return "arrowtriangle.right"
        case .quickSave: return "square.and.arrow.down"
        case .quickLoad: return "square.and.arrow.up"
        case .turboA: return "a.circle.fill"
        case .turboB: return "b.circle.fill"
        }
    }
    
    var category: ButtonCategory {
        switch self {
        case .a, .b, .start, .select: return .action
        case .up, .down, .left, .right: return .dpad
        case .quickSave, .quickLoad, .turboA, .turboB: return .special
        }
    }
    
    enum ButtonCategory: String, CaseIterable {
        case action = "Action Buttons"
        case dpad = "D-Pad"
        case special = "Special"
    }
}

