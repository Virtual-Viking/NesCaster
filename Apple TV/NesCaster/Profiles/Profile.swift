//
//  Profile.swift
//  NesCaster
//
//  Profile data model for multi-user support
//

import Foundation
import SwiftUI

// MARK: - Profile Model

struct Profile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var pictureID: String
    var createdAt: Date
    var lastUsedAt: Date
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(), name: String, pictureID: String = "default_player1") {
        self.id = id
        self.name = name
        self.pictureID = pictureID
        self.createdAt = Date()
        self.lastUsedAt = Date()
    }
    
    // MARK: - Directory Paths
    
    /// Base directory for this profile's data
    var baseDirectory: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("Profiles/\(id.uuidString)")
    }
    
    /// Directory for ROM files
    var romsDirectory: URL {
        baseDirectory.appendingPathComponent("ROMs")
    }
    
    /// Directory for save states
    var savesDirectory: URL {
        baseDirectory.appendingPathComponent("Saves")
    }
    
    /// Directory for auto-saves
    var autoSavesDirectory: URL {
        savesDirectory.appendingPathComponent("AutoSaves")
    }
    
    /// Directory for custom profile pictures
    var customPicturesDirectory: URL {
        baseDirectory.appendingPathComponent("CustomPictures")
    }
    
    /// Path to settings file
    var settingsPath: URL {
        baseDirectory.appendingPathComponent("settings.json")
    }
    
    /// Path to controller mapping file
    var controllerMappingPath: URL {
        baseDirectory.appendingPathComponent("controller.json")
    }
    
    // MARK: - Equatable
    
    static func == (lhs: Profile, rhs: Profile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Profile Settings

struct ProfileSettings: Codable, Equatable {
    // Video
    var scalingMode: ScalingMode = .integerScale
    var showScanlines: Bool = false
    var scanlineIntensity: Double = 0.3
    var showCRTEffect: Bool = false
    
    // Audio
    var masterVolume: Double = 1.0
    var audioLatencyMode: AudioLatencyMode = .low
    var enableSquare1: Bool = true
    var enableSquare2: Bool = true
    var enableTriangle: Bool = true
    var enableNoise: Bool = true
    var enableDMC: Bool = true
    
    // Save States
    var saveHistorySize: Int = 10  // 5, 10, or 15
    var autoSaveEnabled: Bool = true
    var autoSaveOnLevelComplete: Bool = true
    var autoSaveIntervalMinutes: Int = 0  // 0 = disabled
    
    // Display
    var showFPSCounter: Bool = false
    var showFrameTime: Bool = false
    
    // Enums
    enum ScalingMode: String, Codable, CaseIterable, Equatable {
        case integerScale = "Pixel Perfect"
        case aspectFill = "Aspect Fill"
        case stretch = "Stretch"
    }
    
    enum AudioLatencyMode: String, Codable, CaseIterable, Equatable {
        case low = "Low (Gaming)"
        case normal = "Normal"
    }
}

// MARK: - Controller Mapping

struct ControllerMapping: Codable {
    var profileID: UUID
    var controllerID: String?       // nil = any controller
    var controllerName: String?
    
    // NES button mappings (physical button names)
    var buttonA: String = "buttonA"
    var buttonB: String = "buttonB"
    var buttonStart: String = "rightShoulder"
    var buttonSelect: String = "leftShoulder"
    var dpadUp: String = "dpadUp"
    var dpadDown: String = "dpadDown"
    var dpadLeft: String = "dpadLeft"
    var dpadRight: String = "dpadRight"
    
    // Quick action mappings
    var quickSave: String = "leftTrigger"
    var quickLoad: String = "rightTrigger"
    
    // Turbo buttons (optional)
    var turboA: String? = nil
    var turboB: String? = nil
    
    init(profileID: UUID) {
        self.profileID = profileID
    }
}

// MARK: - Profile Picture

struct ProfilePicture: Identifiable, Codable {
    let id: String
    var name: String
    var type: PictureType
    var file: String
    var category: String
    var color: String?  // Accent color for default avatars
    
    enum PictureType: String, Codable {
        case animated
        case `static`
    }
}

// MARK: - Profile Picture Manifest

struct ProfilePictureManifest: Codable {
    var version: String
    var description: String
    var pictures: [ProfilePicture]
    var categories: [PictureCategory]
    
    struct PictureCategory: Codable, Identifiable {
        var id: String
        var name: String
        var description: String
    }
}

