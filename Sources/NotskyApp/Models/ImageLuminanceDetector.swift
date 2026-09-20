import SwiftUI
import AppKit
import CoreImage

public enum ImageLuminanceDetector {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])
    private static var cache: [String: Bool] = [:]
    private static var colorCache: [String: Color] = [:]
    
    public static func isLightImage(at path: String) -> Bool {
        if let cached = cache[path] {
            return cached
        }
        
        // Check wallpaper pack preset
        if let preset = WallpaperPackManager.shared.item(for: path) {
            let isLight = preset.gradientColors.first.map { isLightColor($0) } ?? false
            cache[path] = isLight
            return isLight
        }
        
        guard let cgImage = ImageDownsampler.shared.sampleCGImage(path: path, targetMaxPixelSize: 64) else {
            cache[path] = false
            return false
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        let topCropRect = CGRect(
            x: 0,
            y: extent.height * 0.65,
            width: extent.width,
            height: extent.height * 0.35
        )
        
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: topCropRect)
        ]), let outputImage = filter.outputImage else {
            cache[path] = false
            return false
        }
        
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let isLight = luminance > 0.55
        cache[path] = isLight
        return isLight
    }

    public static func dominantAccentColor(at path: String) -> Color {
        if let cached = colorCache[path] {
            return cached
        }
        
        // Check wallpaper pack preset
        if let preset = WallpaperPackManager.shared.item(for: path) {
            let color = Color(hue: preset.accentHue, saturation: 0.85, brightness: 0.98)
            colorCache[path] = color
            return color
        }
        
        guard let cgImage = ImageDownsampler.shared.sampleCGImage(path: path, targetMaxPixelSize: 64) else {
            let fallback = Color(hue: 0.98, saturation: 0.85, brightness: 0.98) // Bright vibrant coral/pink
            colorCache[path] = fallback
            return fallback
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ]), let outputImage = filter.outputImage else {
            let fallback = Color(hue: 0.98, saturation: 0.85, brightness: 0.98)
            return fallback
        }
        
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        
        let nsColor = NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let finalColor: Color
        if saturation < 0.10 {
            // Low saturation / dark or monochrome image: use a bright, vibrant electric coral-amber
            finalColor = Color(hue: 0.08, saturation: 0.88, brightness: 0.98)
        } else {
            // Boost brightness to the bright side (0.92 - 0.98) and ensure vivid saturation (0.75 - 0.95)
            let brightSaturation = min(max(Double(saturation) * 1.35, 0.75), 0.95)
            let highBrightness = min(max(Double(brightness) * 1.6, 0.92), 0.99)
            finalColor = Color(hue: Double(hue), saturation: brightSaturation, brightness: highBrightness)
        }
        
        colorCache[path] = finalColor
        return finalColor
    }
    
    private static func isLightColor(_ color: Color) -> Bool {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return false }
        let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        return luminance > 0.55
    }
}
