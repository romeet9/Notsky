import SwiftUI
import AppKit
import CoreGraphics

public enum ImageLuminanceDetector {
    // Thread-safe caches
    private static let luminanceCache = NSCache<NSString, NSNumber>()
    private static let colorCache = NSCache<NSString, NSColor>()
    
    public static func isLightImage(at path: String) -> Bool {
        guard !path.isEmpty else { return false }
        
        let nsKey = path as NSString
        if let cached = luminanceCache.object(forKey: nsKey) {
            return cached.boolValue
        }
        
        // Check wallpaper pack preset
        if let preset = WallpaperPackManager.shared.item(for: path) {
            let isLight = preset.gradientColors.first.map { isLightColor($0) } ?? false
            luminanceCache.setObject(NSNumber(value: isLight), forKey: nsKey)
            return isLight
        }
        
        guard let cgImage = ImageDownsampler.shared.sampleCGImage(path: path, targetMaxPixelSize: 64) else {
            luminanceCache.setObject(NSNumber(value: false), forKey: nsKey)
            return false
        }
        
        // Sample top 35% where card header text sits
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel = [UInt8](repeating: 0, count: 4)
        
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            luminanceCache.setObject(NSNumber(value: false), forKey: nsKey)
            return false
        }
        
        context.interpolationQuality = .medium
        let topHeight = CGFloat(cgImage.height) * 0.35
        let topY = CGFloat(cgImage.height) * 0.65
        let cropRect = CGRect(x: 0, y: topY, width: CGFloat(cgImage.width), height: topHeight)
        
        if let cropped = cgImage.cropping(to: cropRect) {
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        } else {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        
        let r = Double(pixel[0]) / 255.0
        let g = Double(pixel[1]) / 255.0
        let b = Double(pixel[2]) / 255.0
        
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let isLight = luminance > 0.55
        
        luminanceCache.setObject(NSNumber(value: isLight), forKey: nsKey)
        return isLight
    }

    public static func dominantAccentColor(at path: String) -> Color {
        guard !path.isEmpty else {
            return Color(hue: 0.98, saturation: 0.85, brightness: 0.98)
        }
        
        let nsKey = path as NSString
        if let cached = colorCache.object(forKey: nsKey) {
            return Color(nsColor: cached)
        }
        
        // Check wallpaper pack preset
        if let preset = WallpaperPackManager.shared.item(for: path) {
            let color = Color(hue: preset.accentHue, saturation: 0.85, brightness: 0.98)
            let nsColor = NSColor(color)
            colorCache.setObject(nsColor, forKey: nsKey)
            return color
        }
        
        guard let cgImage = ImageDownsampler.shared.sampleCGImage(path: path, targetMaxPixelSize: 64) else {
            let fallback = NSColor(hue: 0.98, saturation: 0.85, brightness: 0.98, alpha: 1.0)
            colorCache.setObject(fallback, forKey: nsKey)
            return Color(nsColor: fallback)
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixel = [UInt8](repeating: 0, count: 4)
        
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            let fallback = NSColor(hue: 0.98, saturation: 0.85, brightness: 0.98, alpha: 1.0)
            colorCache.setObject(fallback, forKey: nsKey)
            return Color(nsColor: fallback)
        }
        
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        let r = CGFloat(pixel[0]) / 255.0
        let g = CGFloat(pixel[1]) / 255.0
        let b = CGFloat(pixel[2]) / 255.0
        
        let sampleColor = NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        sampleColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let finalNSColor: NSColor
        if saturation < 0.10 {
            finalNSColor = NSColor(hue: 0.08, saturation: 0.88, brightness: 0.98, alpha: 1.0)
        } else {
            let brightSaturation = min(max(saturation * 1.35, 0.75), 0.95)
            let highBrightness = min(max(brightness * 1.6, 0.92), 0.99)
            finalNSColor = NSColor(hue: hue, saturation: brightSaturation, brightness: highBrightness, alpha: 1.0)
        }
        
        colorCache.setObject(finalNSColor, forKey: nsKey)
        return Color(nsColor: finalNSColor)
    }
    
    private static func isLightColor(_ color: Color) -> Bool {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return false }
        let luminance = 0.2126 * rgb.redComponent + 0.7152 * rgb.greenComponent + 0.0722 * rgb.blueComponent
        return luminance > 0.55
    }
}
