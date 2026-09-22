import SwiftUI
import AppKit

public struct HeaderImageView: View {
    public var imagePath: String
    public var targetMaxPixelSize: CGFloat
    @State private var loadedImage: NSImage? = nil
    
    public init(imagePath: String = WallpaperPackManager.defaultFallbackPath, targetMaxPixelSize: CGFloat = 800) {
        self.imagePath = imagePath
        self.targetMaxPixelSize = targetMaxPixelSize
    }
    
    public var body: some View {
        ZStack {
            // Check if it's a wallpaper pack preset
            if let wallpaperItem = WallpaperPackManager.shared.item(for: imagePath) {
                LinearGradient(
                    colors: wallpaperItem.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(
                    RadialGradient(
                        colors: [Color.white.opacity(0.18), Color.clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 280
                    )
                )
                .overlay(
                    RadialGradient(
                        colors: [Color.black.opacity(0.25), Color.clear],
                        center: .bottomTrailing,
                        startRadius: 40,
                        endRadius: 300
                    )
                )
            } else {
                // Vibrant fallback gradient
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.90, green: 0.12, blue: 0.38), location: 0.0),
                        .init(color: Color(red: 0.98, green: 0.22, blue: 0.48), location: 0.45),
                        .init(color: Color(red: 0.75, green: 0.08, blue: 0.28), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // Loaded Downsampled File Image (HEIC, PNG, JPG)
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.15, anchor: .center)
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: imagePath) { _, _ in
            loadImage()
        }
    }
    
    public static func getImage(for path: String, targetMaxPixelSize: CGFloat = 800) -> NSImage? {
        return ImageDownsampler.shared.downsample(path: path, targetMaxPixelSize: targetMaxPixelSize)
    }
    
    private func loadImage() {
        if imagePath.hasPrefix("preset://") {
            self.loadedImage = nil
            return
        }
        
        if let cached = ImageDownsampler.shared.downsample(path: imagePath, targetMaxPixelSize: targetMaxPixelSize) {
            self.loadedImage = cached
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let img = ImageDownsampler.shared.downsample(path: self.imagePath, targetMaxPixelSize: self.targetMaxPixelSize)
            DispatchQueue.main.async {
                self.loadedImage = img
            }
        }
    }
}
