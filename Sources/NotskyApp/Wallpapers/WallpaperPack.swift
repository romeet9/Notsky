import SwiftUI
import AppKit

public struct WallpaperPack: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let items: [WallpaperItem]
    
    public var previewColors: [Color] {
        items.map { $0.gradientColors.first ?? .red }
    }
}
