//
//  ProfilePicturePickerView.swift
//  NesCaster
//
//  Liquid Glass UI for selecting profile pictures (static + animated)
//

import SwiftUI

struct ProfilePicturePickerView: View {
    
    @ObservedObject var pictureManager: ProfilePictureManager
    @Binding var selectedPictureID: String
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedCategory: String = "default"
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Glass background
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.03, blue: 0.08),
                        Color(red: 0.05, green: 0.04, blue: 0.12),
                        Color(red: 0.03, green: 0.03, blue: 0.07)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // Preview
                    selectedPicturePreview
                    
                    // Category tabs
                    categoryTabs
                    
                    // Picture grid
                    pictureGrid
                }
                .padding(40)
            }
            .navigationTitle("Choose Picture")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Selected Picture Preview
    
    private var selectedPicturePreview: some View {
        let isAnimated = pictureManager.isAnimated(selectedPictureID)
        let color = pictureManager.getColor(for: selectedPictureID)
        
        return VStack(spacing: 16) {
            ZStack {
                // Glass ring
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.6), lineWidth: 3)
                    )
                    .shadow(color: color.opacity(0.4), radius: 25)
                
                // Avatar content
                if isAnimated {
                    LottieView(animationName: selectedPictureID)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.9), color.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Type badge
            HStack(spacing: 8) {
                Image(systemName: isAnimated ? "sparkles" : "circle.fill")
                    .font(.system(size: 12))
                
                Text(isAnimated ? "Animated" : "Static")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isAnimated ? .cyan : .white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial.opacity(0.5))
            )
        }
    }
    
    // MARK: - Category Tabs
    
    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(pictureManager.categories, id: \.id) { category in
                    CategoryTab(
                        title: category.name,
                        isSelected: selectedCategory == category.id,
                        count: pictureManager.getPictures(category: category.id).count
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category.id
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Picture Grid
    
    private var pictureGrid: some View {
        let pictures = pictureManager.getPictures(category: selectedCategory)
        let columns = [
            GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 20)
        ]
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(pictures, id: \.id) { picture in
                    PictureGridItem(
                        picture: picture,
                        isSelected: selectedPictureID == picture.id,
                        pictureManager: pictureManager
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPictureID = picture.id
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }
}

// MARK: - Category Tab

struct CategoryTab: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
                    )
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Color.white.opacity(0.15))
                    } else {
                        Capsule().fill(.ultraThinMaterial.opacity(0.5))
                    }
                }
                .overlay(
                    Capsule()
                        .stroke(
                            isFocused ? Color.white.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
            )
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Picture Grid Item

struct PictureGridItem: View {
    let picture: ProfilePicture
    let isSelected: Bool
    let pictureManager: ProfilePictureManager
    let onTap: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    private var color: Color {
        pictureManager.getColor(for: picture.id)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Picture preview
                ZStack {
                    // Glass background
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected 
                                        ? LinearGradient(colors: [color.opacity(0.9), color.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: isSelected ? 3 : 1
                                )
                        )
                    
                    // Content
                    if picture.type == .animated {
                        LottieView(animationName: picture.id)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.9), color.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                    }
                    
                    // Animated badge
                    if picture.type == .animated {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(
                                        Circle()
                                            .fill(.cyan.opacity(0.8))
                                    )
                                    .shadow(color: .cyan.opacity(0.5), radius: 5)
                            }
                            Spacer()
                        }
                        .frame(width: 100, height: 100)
                    }
                    
                    // Selection checkmark
                    if isSelected {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                    .shadow(color: .green.opacity(0.5), radius: 5)
                            }
                        }
                        .frame(width: 100, height: 100)
                    }
                }
                .shadow(
                    color: isFocused ? color.opacity(0.5) : .clear,
                    radius: 15
                )
                
                // Name
                Text(picture.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfilePicturePickerView(
        pictureManager: ProfilePictureManager.shared,
        selectedPictureID: .constant("default_player1")
    )
    .preferredColorScheme(.dark)
}

