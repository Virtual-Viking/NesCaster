//
//  ProfileSelectionView.swift
//  NesCaster
//
//  Netflix-style profile selection with Liquid Glass UI
//

import SwiftUI

struct ProfileSelectionView: View {
    
    @ObservedObject var profileManager: ProfileManager
    @State private var showingCreateProfile = false
    @State private var showingEditProfile = false
    @State private var profileToEdit: Profile?
    @State private var isManageMode = false
    @State private var animateIn = false
    
    var onProfileSelected: (Profile) -> Void
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Animated background
            liquidGlassBackground
            
            VStack(spacing: 60) {
                // Header with glass effect
                headerView
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : -30)
                
                // Profile Grid
                profileGrid
                    .opacity(animateIn ? 1 : 0)
                    .scaleEffect(animateIn ? 1 : 0.9)
                
                // Manage Button
                if !profileManager.profiles.isEmpty {
                    manageButton
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                }
            }
            .padding(80)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateIn = true
            }
        }
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView(profileManager: profileManager)
        }
        .sheet(item: $profileToEdit) { profile in
            EditProfileView(profileManager: profileManager, profile: profile)
        }
    }
    
    // MARK: - Liquid Glass Background
    
    private var liquidGlassBackground: some View {
        ZStack {
            // Deep base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.06, green: 0.04, blue: 0.14),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated orbs for liquid effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.9, green: 0.25, blue: 0.4).opacity(0.4),
                            Color(red: 0.9, green: 0.25, blue: 0.4).opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .blur(radius: 80)
                .offset(x: -200, y: -300)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.3, green: 0.4, blue: 0.9).opacity(0.3),
                            Color(red: 0.3, green: 0.4, blue: 0.9).opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .blur(radius: 60)
                .offset(x: 300, y: 200)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 50)
                .offset(x: -100, y: 300)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 20) {
            Text("Who's Playing?")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            if isManageMode {
                Text("Select a profile to edit or delete")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
            }
        }
    }
    
    // MARK: - Profile Grid
    
    private var profileGrid: some View {
        HStack(spacing: 50) {
            // Existing profiles
            ForEach(profileManager.profiles) { profile in
                GlassProfileCard(
                    profile: profile,
                    isManageMode: isManageMode,
                    onSelect: {
                        if isManageMode {
                            profileToEdit = profile
                        } else {
                            onProfileSelected(profile)
                        }
                    }
                )
            }
            
            // Add profile button (if under limit)
            if profileManager.profiles.count < ProfileManager.maxProfiles && !isManageMode {
                GlassAddProfileCard {
                    showingCreateProfile = true
                }
            }
        }
    }
    
    // MARK: - Manage Button
    
    private var manageButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isManageMode.toggle()
            }
        }) {
            Text(isManageMode ? "Done" : "Manage Profiles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Profile Card

struct GlassProfileCard: View {
    let profile: Profile
    let isManageMode: Bool
    let onSelect: () -> Void
    
    @Environment(\.isFocused) var isFocused
    @StateObject private var pictureManager = ProfilePictureManager.shared
    
    private var profileColor: Color {
        pictureManager.getColor(for: profile.pictureID)
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 20) {
                // Avatar with glass ring
                ZStack {
                    // Outer glass ring
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 180, height: 180)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: isFocused 
                                            ? [profileColor.opacity(0.8), profileColor.opacity(0.4)]
                                            : [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isFocused ? 4 : 2
                                )
                        )
                        .shadow(
                            color: isFocused ? profileColor.opacity(0.5) : .clear,
                            radius: 30
                        )
                    
                    // Inner colored circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    profileColor.opacity(0.9),
                                    profileColor.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 150, height: 150)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    // Initial letter
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    
                    // Edit indicator overlay
                    if isManageMode {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 150, height: 150)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                // Name with glass pill
                VStack(spacing: 8) {
                    Text(profile.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isFocused ? .white : .white.opacity(0.85))
                    
                    Text("\(getROMCount()) games")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial.opacity(0.5))
                        )
                }
            }
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(.plain)
    }
    
    private func getROMCount() -> Int {
        return 0
    }
}

// MARK: - Glass Add Profile Card

struct GlassAddProfileCard: View {
    let onTap: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 20) {
                // Glass circle with plus
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 180, height: 180)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: isFocused 
                                            ? [.white.opacity(0.6), .white.opacity(0.3)]
                                            : [.white.opacity(0.25), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: isFocused ? 3 : 2
                                )
                        )
                        .shadow(
                            color: isFocused ? Color.white.opacity(0.2) : .clear,
                            radius: 25
                        )
                    
                    Image(systemName: "plus")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white.opacity(isFocused ? 0.9 : 0.6), .white.opacity(isFocused ? 0.7 : 0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Label
                VStack(spacing: 8) {
                    Text("Add Profile")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isFocused ? .white : .white.opacity(0.7))
                    
                    Text("New player")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial.opacity(0.3))
                        )
                }
            }
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Profile View (Glass)

struct CreateProfileView: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var selectedPictureID: String
    @FocusState private var isNameFieldFocused: Bool
    
    init(profileManager: ProfileManager) {
        self.profileManager = profileManager
        _selectedPictureID = State(initialValue: profileManager.getDefaultPictureID())
    }
    
    private var isValidName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 1 && trimmed.count <= 20 && profileManager.isNameAvailable(trimmed)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Glass background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.12),
                        Color(red: 0.08, green: 0.06, blue: 0.16),
                        Color(red: 0.04, green: 0.04, blue: 0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 50) {
                    // Preview
                    profilePreview
                    
                    // Name input with glass
                    VStack(spacing: 12) {
                        Text("Profile Name")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Enter name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .focused($isNameFieldFocused)
                            .frame(maxWidth: 400)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    
                    // Color selection
                    colorSelector
                    
                    // Create button (glass)
                    Button(action: createProfile) {
                        Text("Create Profile")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 48)
                            .padding(.vertical, 18)
                            .background(
                                Capsule()
                                    .fill(
                                        isValidName 
                                            ? LinearGradient(
                                                colors: [Color(red: 0.9, green: 0.3, blue: 0.4), Color(red: 0.8, green: 0.2, blue: 0.5)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                            : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: isValidName ? Color(red: 0.9, green: 0.3, blue: 0.4).opacity(0.4) : .clear, radius: 20)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValidName)
                }
                .padding(60)
            }
            .navigationTitle("New Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
    }
    
    private var profilePreview: some View {
        let color = ProfilePictureManager.shared.getColor(for: selectedPictureID)
        
        return ZStack {
            // Glass ring
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 160, height: 160)
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.5), lineWidth: 3)
                )
                .shadow(color: color.opacity(0.4), radius: 25)
            
            // Inner circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.9), color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 130, height: 130)
            
            Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private var colorSelector: some View {
        VStack(spacing: 12) {
            Text("Choose Color")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(spacing: 24) {
                ForEach(["default_player1", "default_player2", "default_player3", "default_player4"], id: \.self) { pictureID in
                    let color = ProfilePictureManager.shared.getColor(for: pictureID)
                    let isSelected = selectedPictureID == pictureID
                    
                    Button(action: { selectedPictureID = pictureID }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 60, height: 60)
                            
                            Circle()
                                .fill(color)
                                .frame(width: 46, height: 46)
                            
                            if isSelected {
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 60, height: 60)
                            }
                        }
                        .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 15)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func createProfile() {
        guard isValidName else { return }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let profile = profileManager.createProfile(name: trimmedName, pictureID: selectedPictureID) {
            profileManager.switchToProfile(profile)
            dismiss()
        }
    }
}

// MARK: - Edit Profile View (Glass)

struct EditProfileView: View {
    @ObservedObject var profileManager: ProfileManager
    let profile: Profile
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var selectedPictureID: String
    @State private var showingDeleteConfirmation = false
    
    init(profileManager: ProfileManager, profile: Profile) {
        self.profileManager = profileManager
        self.profile = profile
        _name = State(initialValue: profile.name)
        _selectedPictureID = State(initialValue: profile.pictureID)
    }
    
    private var isValidName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 1 && trimmed.count <= 20 && profileManager.isNameAvailable(trimmed, excluding: profile.id)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.12),
                        Color(red: 0.08, green: 0.06, blue: 0.16),
                        Color(red: 0.04, green: 0.04, blue: 0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 50) {
                    profilePreview
                    
                    // Name input
                    VStack(spacing: 12) {
                        Text("Profile Name")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Enter name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    
                    colorSelector
                    
                    // Buttons
                    HStack(spacing: 30) {
                        Button(action: saveProfile) {
                            Text("Save Changes")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(
                                            isValidName
                                                ? LinearGradient(colors: [Color(red: 0.9, green: 0.3, blue: 0.4), Color(red: 0.8, green: 0.2, blue: 0.5)], startPoint: .leading, endPoint: .trailing)
                                                : LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isValidName)
                        
                        Button(action: { showingDeleteConfirmation = true }) {
                            Text("Delete")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Capsule().stroke(Color.red.opacity(0.5), lineWidth: 2))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(60)
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Delete Profile?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    profileManager.deleteProfile(profile)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete \"\(profile.name)\" and all saved games.")
            }
        }
    }
    
    private var profilePreview: some View {
        let color = ProfilePictureManager.shared.getColor(for: selectedPictureID)
        
        return ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 160, height: 160)
                .overlay(Circle().stroke(color.opacity(0.5), lineWidth: 3))
                .shadow(color: color.opacity(0.4), radius: 25)
            
            Circle()
                .fill(LinearGradient(colors: [color.opacity(0.9), color.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 130, height: 130)
            
            Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private var colorSelector: some View {
        VStack(spacing: 12) {
            Text("Choose Color")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(spacing: 24) {
                ForEach(["default_player1", "default_player2", "default_player3", "default_player4"], id: \.self) { pictureID in
                    let color = ProfilePictureManager.shared.getColor(for: pictureID)
                    let isSelected = selectedPictureID == pictureID
                    
                    Button(action: { selectedPictureID = pictureID }) {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 60, height: 60)
                            Circle().fill(color).frame(width: 46, height: 46)
                            if isSelected {
                                Circle().stroke(Color.white, lineWidth: 3).frame(width: 60, height: 60)
                            }
                        }
                        .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 15)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func saveProfile() {
        guard isValidName else { return }
        var updatedProfile = profile
        updatedProfile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProfile.pictureID = selectedPictureID
        profileManager.updateProfile(updatedProfile)
        dismiss()
    }
}

#Preview {
    ProfileSelectionView(profileManager: ProfileManager()) { profile in
        print("Selected: \(profile.name)")
    }
}
