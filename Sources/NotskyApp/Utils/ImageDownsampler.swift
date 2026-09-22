import SwiftUI
import AppKit
import ImageIO

public final class ImageDownsampler {
    public static let shared = ImageDownsampler()
    
    // Memory-capped NSCache (Evicts oldest when memory pressure or limit is reached)
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 60
        cache.totalCostLimit = 48 * 1024 * 1024 // 48 MB maximum memory allocation
    }
    
    /// Returns a downsampled NSImage for a given file path.
    /// targetMaxPixelSize: 800 for card headers / underlays, 200 for settings previews.
    public func downsample(path: String, targetMaxPixelSize: CGFloat = 800) -> NSImage? {
        if path.isEmpty || path.hasPrefix("preset://") {
            return nil
        }
        
        let cacheKey = "\(path)_\(Int(targetMaxPixelSize))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        var cleanPath = path
        if cleanPath.hasPrefix("file://") {
            cleanPath = URL(string: cleanPath)?.path ?? cleanPath.replacingOccurrences(of: "file://", with: "")
        }
        if let decoded = cleanPath.removingPercentEncoding, FileManager.default.fileExists(atPath: decoded) {
            cleanPath = decoded
        }
        guard FileManager.default.fileExists(atPath: cleanPath) else {
            return nil
        }
        
        let fileURL = URL(fileURLWithPath: cleanPath)
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, sourceOptions) else {
            return nil
        }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetMaxPixelSize
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }
        
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let image = NSImage(cgImage: cgImage, size: size)
        
        // Exact cost in bytes (width * height * 4 bytes per RGBA pixel)
        let cost = cgImage.width * cgImage.height * 4
        cache.setObject(image, forKey: cacheKey, cost: cost)
        
        return image
    }
    
    /// Creates a tiny CGImage directly for luminance / accent color extraction without UI overhead
    public func sampleCGImage(path: String, targetMaxPixelSize: CGFloat = 64) -> CGImage? {
        if path.isEmpty || path.hasPrefix("preset://") {
            return nil
        }
        
        var cleanPath = path
        if cleanPath.hasPrefix("file://") {
            cleanPath = URL(string: cleanPath)?.path ?? cleanPath.replacingOccurrences(of: "file://", with: "")
        }
        if let decoded = cleanPath.removingPercentEncoding, FileManager.default.fileExists(atPath: decoded) {
            cleanPath = decoded
        }
        guard FileManager.default.fileExists(atPath: cleanPath) else {
            return nil
        }
        
        let fileURL = URL(fileURLWithPath: cleanPath)
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, sourceOptions) else {
            return nil
        }
        
        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetMaxPixelSize
        ]
        
        return CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary)
    }
    
    public func clearCache() {
        cache.removeAllObjects()
    }
}
