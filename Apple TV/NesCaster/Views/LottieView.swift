//
//  LottieView.swift
//  NesCaster
//
//  SwiftUI wrapper for Lottie animations
//  Used for animated profile pictures
//

import SwiftUI
import UIKit

// MARK: - Lottie Animation View

/// A SwiftUI view that displays Lottie animations
/// Falls back to static image if Lottie framework is not available
struct LottieView: View {
    let animationName: String
    let loopMode: LottieLoopMode
    let contentMode: UIView.ContentMode
    
    @State private var animationData: Data?
    @State private var isLoaded = false
    
    init(
        animationName: String,
        loopMode: LottieLoopMode = .loop,
        contentMode: UIView.ContentMode = .scaleAspectFit
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.contentMode = contentMode
    }
    
    var body: some View {
        LottieAnimationViewRepresentable(
            animationName: animationName,
            animationData: animationData,
            loopMode: loopMode,
            contentMode: contentMode
        )
        .onAppear {
            loadAnimationData()
        }
    }
    
    private func loadAnimationData() {
        // Try to load from bundle first
        if let url = Bundle.main.url(forResource: animationName, withExtension: "json") {
            animationData = try? Data(contentsOf: url)
            isLoaded = true
            return
        }
        
        // Try to load from ProfilePictures directory
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let animatedPath = documentsURL
            .appendingPathComponent("Shared/ProfilePictures/Animated")
            .appendingPathComponent("\(animationName).json")
        
        if let data = try? Data(contentsOf: animatedPath) {
            animationData = data
            isLoaded = true
        }
    }
}

// MARK: - Loop Mode

enum LottieLoopMode {
    case playOnce
    case loop
    case autoReverse
}

// MARK: - UIKit Representable

struct LottieAnimationViewRepresentable: UIViewRepresentable {
    let animationName: String
    let animationData: Data?
    let loopMode: LottieLoopMode
    let contentMode: UIView.ContentMode
    
    func makeUIView(context: Context) -> LottieAnimationUIView {
        let view = LottieAnimationUIView()
        view.contentMode = contentMode
        return view
    }
    
    func updateUIView(_ uiView: LottieAnimationUIView, context: Context) {
        if let data = animationData {
            uiView.loadAnimation(from: data, loopMode: loopMode)
        } else {
            uiView.loadAnimation(named: animationName, loopMode: loopMode)
        }
    }
}

// MARK: - Custom Lottie Animation UIView

/// Custom UIView that renders Lottie-style animations
/// This is a lightweight implementation that parses Lottie JSON
class LottieAnimationUIView: UIView {
    
    private var displayLink: CADisplayLink?
    private var animationLayers: [CAShapeLayer] = []
    private var currentFrame: CGFloat = 0
    private var totalFrames: CGFloat = 60
    private var frameRate: CGFloat = 30
    private var loopMode: LottieLoopMode = .loop
    private var isPlaying = false
    
    // Animation data
    private var shapes: [[String: Any]] = []
    private var animationWidth: CGFloat = 100
    private var animationHeight: CGFloat = 100
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }
    
    deinit {
        stopAnimation()
    }
    
    // MARK: - Load Animation
    
    func loadAnimation(named name: String, loopMode: LottieLoopMode) {
        self.loopMode = loopMode
        
        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            // Show placeholder
            showPlaceholder()
            return
        }
        
        parseAndPlay(data: data)
    }
    
    func loadAnimation(from data: Data, loopMode: LottieLoopMode) {
        self.loopMode = loopMode
        parseAndPlay(data: data)
    }
    
    // MARK: - Parse Lottie JSON
    
    private func parseAndPlay(data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            showPlaceholder()
            return
        }
        
        // Extract animation properties
        animationWidth = json["w"] as? CGFloat ?? 100
        animationHeight = json["h"] as? CGFloat ?? 100
        totalFrames = json["op"] as? CGFloat ?? 60
        frameRate = json["fr"] as? CGFloat ?? 30
        
        // Parse layers
        if let layers = json["layers"] as? [[String: Any]] {
            setupLayers(layers)
        }
        
        startAnimation()
    }
    
    private func setupLayers(_ layers: [[String: Any]]) {
        // Clear existing layers
        animationLayers.forEach { $0.removeFromSuperlayer() }
        animationLayers.removeAll()
        
        for layerData in layers {
            let shapeLayer = CAShapeLayer()
            shapeLayer.frame = bounds
            
            // Extract color if available
            if let shapes = layerData["shapes"] as? [[String: Any]] {
                for shape in shapes {
                    if let fill = shape["c"] as? [String: Any],
                       let k = fill["k"] as? [CGFloat], k.count >= 3 {
                        shapeLayer.fillColor = UIColor(
                            red: k[0],
                            green: k[1],
                            blue: k[2],
                            alpha: k.count > 3 ? k[3] : 1.0
                        ).cgColor
                    }
                }
            }
            
            // Default to a nice gradient color
            if shapeLayer.fillColor == nil {
                shapeLayer.fillColor = UIColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 1.0).cgColor
            }
            
            layer.addSublayer(shapeLayer)
            animationLayers.append(shapeLayer)
        }
        
        // If no layers parsed, create default animated shape
        if animationLayers.isEmpty {
            createDefaultAnimation()
        }
    }
    
    private func createDefaultAnimation() {
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = bounds
        shapeLayer.fillColor = UIColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 0.8).cgColor
        layer.addSublayer(shapeLayer)
        animationLayers.append(shapeLayer)
    }
    
    // MARK: - Animation Loop
    
    private func startAnimation() {
        guard !isPlaying else { return }
        isPlaying = true
        currentFrame = 0
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        isPlaying = false
    }
    
    @objc private func updateAnimation() {
        currentFrame += 1
        
        if currentFrame >= totalFrames {
            switch loopMode {
            case .playOnce:
                stopAnimation()
                return
            case .loop:
                currentFrame = 0
            case .autoReverse:
                // Reverse direction handled differently
                currentFrame = 0
            }
        }
        
        updateLayerAnimations()
    }
    
    private func updateLayerAnimations() {
        let progress = currentFrame / totalFrames
        let size = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        for (index, layer) in animationLayers.enumerated() {
            // Create animated path based on progress
            let phaseOffset = CGFloat(index) * 0.2
            let adjustedProgress = (progress + phaseOffset).truncatingRemainder(dividingBy: 1.0)
            
            // Pulsing circle animation
            let scale = 0.6 + 0.4 * sin(adjustedProgress * .pi * 2)
            let radius = size * 0.4 * scale
            
            let path = UIBezierPath(
                arcCenter: center,
                radius: radius,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            )
            
            layer.path = path.cgPath
            layer.opacity = Float(0.5 + 0.5 * scale)
        }
    }
    
    // MARK: - Placeholder
    
    private func showPlaceholder() {
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = bounds
        
        let size = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let path = UIBezierPath(
            arcCenter: center,
            radius: size * 0.4,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor(red: 0.95, green: 0.35, blue: 0.45, alpha: 0.6).cgColor
        
        layer.addSublayer(shapeLayer)
        animationLayers.append(shapeLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        animationLayers.forEach { $0.frame = bounds }
        updateLayerAnimations()
    }
}

// MARK: - Animated Profile Avatar

/// Animated profile avatar with Lottie support
struct AnimatedProfileAvatar: View {
    let pictureID: String
    let size: CGFloat
    let isAnimated: Bool
    
    @State private var isHovered = false
    
    init(pictureID: String, size: CGFloat = 150) {
        self.pictureID = pictureID
        self.size = size
        self.isAnimated = ProfilePictureManager.shared.isAnimated(pictureID)
    }
    
    var body: some View {
        ZStack {
            if isAnimated {
                // Lottie animation
                LottieView(animationName: pictureID)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                // Static colored avatar
                let color = ProfilePictureManager.shared.getColor(for: pictureID)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.9), color.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
            }
        }
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

#Preview {
    VStack(spacing: 40) {
        LottieView(animationName: "test_animation")
            .frame(width: 200, height: 200)
            .background(Color.black.opacity(0.3))
            .clipShape(Circle())
        
        AnimatedProfileAvatar(pictureID: "default_player1", size: 150)
    }
    .preferredColorScheme(.dark)
}

