import SwiftUI
import AppKit

public struct WallpaperItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let gradientColors: [Color]
    public let accentHue: Double
    
    public init(
        id: String,
        name: String,
        path: String,
        gradientColors: [Color],
        accentHue: Double
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.gradientColors = gradientColors
        self.accentHue = accentHue
    }
}
