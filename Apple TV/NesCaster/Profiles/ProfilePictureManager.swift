//
//  ProfilePictureManager.swift
//  NesCaster
//
//  Manages profile picture library (static + animated Lottie)
//

import Foundation
import SwiftUI

// MARK: - Profile Picture Manager

@MainActor
class ProfilePictureManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var pictures: [ProfilePicture] = []
    @Published private(set) var categories: [ProfilePictureManifest.PictureCategory] = []
    @Published private(set) var isLoaded = false
    
    // MARK: - Singleton
    
    static let shared = ProfilePictureManager()
    
    // MARK: - Default Pictures (Built-in)
    
    private let defaultPictures: [ProfilePicture] = [
        // Static colored avatars
        ProfilePicture(id: "default_player1", name: "Player 1", type: .static, file: "", category: "default", color: "#E74C3C"),
        ProfilePicture(id: "default_player2", name: "Player 2", type: .static, file: "", category: "default", color: "#3498DB"),
        ProfilePicture(id: "default_player3", name: "Player 3", type: .static, file: "", category: "default", color: "#2ECC71"),
        ProfilePicture(id: "default_player4", name: "Player 4", type: .static, file: "", category: "default", color: "#9B59B6"),
        
        // Animated avatars (Lottie)
        ProfilePicture(id: "anim_gamer", name: "Gamer", type: .animated, file: "anim_gamer.json", category: "characters", color: "#F39C12"),
        ProfilePicture(id: "anim_retro", name: "Retro", type: .animated, file: "anim_retro.json", category: "retro", color: "#1ABC9C"),
        ProfilePicture(id: "anim_pixel", name: "Pixel", type: .animated, file: "anim_pixel.json", category: "retro", color: "#E91E63"),
        ProfilePicture(id: "anim_neon", name: "Neon", type: .animated, file: "anim_neon.json", category: "characters", color: "#00BCD4"),
    ]
    
    private let defaultCategories: [ProfilePictureManifest.PictureCategory] = [
        .init(id: "default", name: "Default", description: "Default player avatars"),
        .init(id: "characters", name: "Animated", description: "Animated characters"),
        .init(id: "retro", name: "Retro", description: "Classic gaming icons"),
        .init(id: "custom", name: "Custom", description: "Your uploaded pictures"),
    ]
    
    // MARK: - Initialization
    
    private init() {
        loadPictures()
    }
    
    // MARK: - Loading
    
    func loadPictures() {
        // Start with defaults
        pictures = defaultPictures
        categories = defaultCategories
        
        // Try to load from bundle manifest
        if let manifestURL = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "ProfilePictures") {
            loadFromManifest(url: manifestURL)
        }
        
        // Scan ProfilePictures directories for additional files
        scanProfilePicturesDirectory()
        
        isLoaded = true
        print("📷 ProfilePictureManager: Loaded \(pictures.count) pictures in \(categories.count) categories")
    }
    
    private func loadFromManifest(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode(ProfilePictureManifest.self, from: data)
            
            // Merge with defaults (don't replace defaults)
            for picture in manifest.pictures where !pictures.contains(where: { $0.id == picture.id }) {
                pictures.append(picture)
            }
            
            for category in manifest.categories where !categories.contains(where: { $0.id == category.id }) {
                categories.append(category)
            }
            
            print("📷 Loaded \(manifest.pictures.count) pictures from manifest")
        } catch {
            print("⚠️ Failed to load manifest: \(error)")
        }
    }
    
    private func scanProfilePicturesDirectory() {
        // Scan bundle for Lottie JSON files
        if let resourcePath = Bundle.main.resourcePath {
            let animatedPath = (resourcePath as NSString).appendingPathComponent("ProfilePictures/Animated")
            scanDirectory(at: URL(fileURLWithPath: animatedPath), type: .animated, category: "characters")
            
            let staticPath = (resourcePath as NSString).appendingPathComponent("ProfilePictures/Static")
            scanDirectory(at: URL(fileURLWithPath: staticPath), type: .static, category: "retro")
        }
        
        // Scan documents directory for user-added pictures
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sharedAnimatedPath = documentsURL.appendingPathComponent("Shared/ProfilePictures/Animated")
        let sharedStaticPath = documentsURL.appendingPathComponent("Shared/ProfilePictures/Static")
        
        scanDirectory(at: sharedAnimatedPath, type: .animated, category: "characters")
        scanDirectory(at: sharedStaticPath, type: .static, category: "retro")
    }
    
    private func scanDirectory(at url: URL, type: ProfilePicture.PictureType, category: String) {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: url.path),
              let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return
        }
        
        for fileURL in contents {
            let ext = fileURL.pathExtension.lowercased()
            let validExtensions = type == .animated ? ["json"] : ["png", "jpg", "jpeg", "svg"]
            
            guard validExtensions.contains(ext) else { continue }
            
            let pictureID = fileURL.deletingPathExtension().lastPathComponent
            
            // Skip if already exists
            guard !pictures.contains(where: { $0.id == pictureID }) else { continue }
            
            let picture = ProfilePicture(
                id: pictureID,
                name: pictureID.replacingOccurrences(of: "_", with: " ").capitalized,
                type: type,
                file: fileURL.lastPathComponent,
                category: category
            )
            
            pictures.append(picture)
            print("📷 Found picture: \(pictureID) (\(type))")
        }
    }
    
    // MARK: - Picture Access
    
    /// Get a picture by ID
    func getPicture(id: String) -> ProfilePicture? {
        pictures.first { $0.id == id }
    }
    
    /// Get pictures by category
    func getPictures(category: String) -> [ProfilePicture] {
        pictures.filter { $0.category == category }
    }
    
    /// Get all animated pictures
    func getAnimatedPictures() -> [ProfilePicture] {
        pictures.filter { $0.type == .animated }
    }
    
    /// Get all static pictures
    func getStaticPictures() -> [ProfilePicture] {
        pictures.filter { $0.type == .static }
    }
    
    /// Check if a picture is animated
    func isAnimated(_ pictureID: String) -> Bool {
        getPicture(id: pictureID)?.type == .animated
    }
    
    /// Get the color for a picture (used for default avatars)
    func getColor(for pictureID: String) -> Color {
        guard let picture = getPicture(id: pictureID),
              let hexColor = picture.color else {
            // Generate a color from the ID for consistency
            return generateColor(from: pictureID)
        }
        return Color(hex: hexColor) ?? generateColor(from: pictureID)
    }
    
    /// Generate a consistent color from a string
    private func generateColor(from string: String) -> Color {
        let hash = abs(string.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
    
    /// Get the animation file URL for a picture
    func getAnimationURL(for pictureID: String) -> URL? {
        guard let picture = getPicture(id: pictureID),
              picture.type == .animated,
              !picture.file.isEmpty else {
            return nil
        }
        
        // Check bundle first
        if let bundleURL = Bundle.main.url(forResource: picture.id, withExtension: "json") {
            return bundleURL
        }
        
        // Check ProfilePictures/Animated directory
        if let bundleURL = Bundle.main.url(forResource: picture.file.replacingOccurrences(of: ".json", with: ""), 
                                           withExtension: "json", 
                                           subdirectory: "ProfilePictures/Animated") {
            return bundleURL
        }
        
        // Check documents directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localURL = documentsURL.appendingPathComponent("Shared/ProfilePictures/Animated/\(picture.file)")
        
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }
        
        return nil
    }
    
    // MARK: - Custom Pictures
    
    /// Add a custom picture for a profile
    func addCustomPicture(data: Data, name: String, isAnimated: Bool, to profile: Profile) -> ProfilePicture? {
        let pictureID = "custom_\(UUID().uuidString)"
        let ext = isAnimated ? "json" : "png"
        let fileName = "\(pictureID).\(ext)"
        let filePath = profile.customPicturesDirectory.appendingPathComponent(fileName)
        
        do {
            // Create directory if needed
            try FileManager.default.createDirectory(
                at: profile.customPicturesDirectory,
                withIntermediateDirectories: true
            )
            
            try data.write(to: filePath)
            
            let picture = ProfilePicture(
                id: pictureID,
                name: name,
                type: isAnimated ? .animated : .static,
                file: filePath.path,
                category: "custom"
            )
            
            pictures.append(picture)
            print("📷 Added custom picture: \(name)")
            return picture
            
        } catch {
            print("❌ Failed to save custom picture: \(error)")
            return nil
        }
    }
    
    /// Load custom pictures for a profile
    func loadCustomPictures(for profile: Profile) {
        let fileManager = FileManager.default
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(
            at: profile.customPicturesDirectory,
            withIntermediateDirectories: true
        )
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: profile.customPicturesDirectory,
                includingPropertiesForKeys: nil
            )
            
            for fileURL in contents {
                let ext = fileURL.pathExtension.lowercased()
                let isAnimated = ext == "json"
                let isStatic = ["png", "jpg", "jpeg"].contains(ext)
                
                guard isAnimated || isStatic else { continue }
                
                let pictureID = fileURL.deletingPathExtension().lastPathComponent
                
                // Skip if already loaded
                guard !pictures.contains(where: { $0.id == pictureID }) else { continue }
                
                let picture = ProfilePicture(
                    id: pictureID,
                    name: fileURL.deletingPathExtension().lastPathComponent,
                    type: isAnimated ? .animated : .static,
                    file: fileURL.path,
                    category: "custom"
                )
                
                pictures.append(picture)
            }
            
        } catch {
            print("⚠️ Failed to load custom pictures: \(error)")
        }
    }
    
    /// Remove a custom picture
    func removeCustomPicture(id: String) {
        guard let picture = getPicture(id: id),
              picture.category == "custom",
              !picture.file.isEmpty else {
            return
        }
        
        // Delete file
        try? FileManager.default.removeItem(atPath: picture.file)
        
        // Remove from list
        pictures.removeAll { $0.id == id }
        print("🗑️ Removed custom picture: \(id)")
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}
