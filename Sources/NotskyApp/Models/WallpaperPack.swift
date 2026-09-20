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

public struct WallpaperPack: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let items: [WallpaperItem]
    
    public var previewColors: [Color] {
        items.map { $0.gradientColors.first ?? .red }
    }
}

@Observable
public final class WallpaperPackManager {
    public static let shared = WallpaperPackManager()
    
    private let kActivePack = "notsky.activeWallpaperPack"
    private let kAllocationCounter = "notsky.wallpaperAllocationCounter"
    private let kCustomFolderPath = "notsky.customWallpaperFolder"
    
    public var packs: [WallpaperPack] = []
    
    public var activePackId: String {
        didSet {
            UserDefaults.standard.set(activePackId, forKey: kActivePack)
        }
    }
    
    public var customFolderPath: String? {
        didSet {
            UserDefaults.standard.set(customFolderPath, forKey: kCustomFolderPath)
            reloadCustomPack()
        }
    }
    
    private var allocationIndex: Int = 0
    
    private init() {
        self.activePackId = UserDefaults.standard.string(forKey: kActivePack) ?? "raycast_distortion"
        self.customFolderPath = UserDefaults.standard.string(forKey: kCustomFolderPath)
        self.allocationIndex = UserDefaults.standard.integer(forKey: kAllocationCounter)
        
        self.packs = Self.builtInPacks()
        reloadCustomPack()
    }
    
    public var activePack: WallpaperPack {
        packs.first(where: { $0.id == activePackId }) ?? packs.first!
    }
    
    /// Get the next sequential wallpaper from the active pack when creating a new group
    public func nextWallpaperPath() -> String {
        let items = activePack.items
        guard !items.isEmpty else {
            return "/Users/romeet/Downloads/red_distortion_2.heic"
        }
        
        let item = items[allocationIndex % items.count]
        allocationIndex += 1
        UserDefaults.standard.set(allocationIndex, forKey: kAllocationCounter)
        
        return item.path
    }
    
    /// Cycles through all wallpapers from the pack containing the current wallpaper (or active pack)
    public func cycleNextWallpaper(after currentPath: String) -> String {
        let pack = packs.first(where: { p in
            p.items.contains(where: { $0.path == currentPath || $0.id == currentPath })
        }) ?? activePack
        
        let items = pack.items
        guard !items.isEmpty else {
            return currentPath
        }
        
        if let currentIndex = items.firstIndex(where: { $0.path == currentPath || $0.id == currentPath }) {
            let nextIndex = (currentIndex + 1) % items.count
            return items[nextIndex].path
        } else {
            return items[0].path
        }
    }
    
    /// Get wallpaper item for path or preset
    public func item(for path: String) -> WallpaperItem? {
        for pack in packs {
            if let found = pack.items.first(where: { $0.path == path || $0.id == path }) {
                return found
            }
        }
        return nil
    }
    
    public func selectPack(id: String) {
        self.activePackId = id
        SensoryFeedback.buttonClicked()
    }
    
    public func applyActivePackToAllNotes(store: NoteStore) {
        let items = activePack.items
        guard !items.isEmpty else { return }
        
        for index in store.notes.indices {
            let item = items[index % items.count]
            store.notes[index].headerImagePath = item.path
        }
        SensoryFeedback.taskCompleted()
    }
    
    public func setCustomFolder(url: URL) {
        self.customFolderPath = url.path
        reloadCustomPack()
        self.activePackId = "custom_folder"
        SensoryFeedback.taskCompleted()
    }
    
    private func reloadCustomPack() {
        guard let folder = customFolderPath, FileManager.default.fileExists(atPath: folder) else { return }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: folder)
            let imageExtensions = ["png", "jpg", "jpeg", "heic", "webp"]
            let imageFiles = files.filter { file in
                let ext = (file as NSString).pathExtension.lowercased()
                return imageExtensions.contains(ext)
            }.sorted()
            
            if !imageFiles.isEmpty {
                var customItems: [WallpaperItem] = []
                for (idx, file) in imageFiles.enumerated() {
                    let fullPath = (folder as NSString).appendingPathComponent(file)
                    let name = (file as NSString).deletingPathExtension
                    let hue = Double(idx) / Double(imageFiles.count)
                    let fallbackColor = Color(hue: hue, saturation: 0.8, brightness: 0.9)
                    customItems.append(WallpaperItem(
                        id: "custom_\(idx)",
                        name: name,
                        path: fullPath,
                        gradientColors: [fallbackColor, fallbackColor.opacity(0.8)],
                        accentHue: hue
                    ))
                }
                
                let customPack = WallpaperPack(
                    id: "custom_folder",
                    name: "Custom Folder Pack",
                    description: "\(customItems.count) wallpapers from \(URL(fileURLWithPath: folder).lastPathComponent)",
                    items: customItems
                )
                
                // Replace or append custom pack
                if let idx = packs.firstIndex(where: { $0.id == "custom_folder" }) {
                    packs[idx] = customPack
                } else {
                    packs.append(customPack)
                }
            }
        } catch {
            // Ignore error
        }
    }
    
    public static var wallpapersDirectory: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Notsky/Wallpapers").path
        if FileManager.default.fileExists(atPath: appSupport) {
            return appSupport
        }
        if let bundleResourcePath = Bundle.main.resourcePath {
            let bundleWallpapers = (bundleResourcePath as NSString).appendingPathComponent("Wallpapers")
            if FileManager.default.fileExists(atPath: bundleWallpapers) {
                return bundleWallpapers
            }
        }
        return "/Users/romeet/.gemini/antigravity/scratch/NotskyApp/Resources/Wallpapers"
    }
    
    private static func wallpaperPath(_ filename: String) -> String {
        (wallpapersDirectory as NSString).appendingPathComponent(filename)
    }
    
    public static func builtInPacks() -> [WallpaperPack] {
        return [
            // Pack 1: Raycast Distortions (All Official 6K)
            WallpaperPack(
                id: "raycast_distortion",
                name: "Raycast Distortions",
                description: "Official 6K liquid crimson and deep electric blue distortion wallpapers by Raycast.",
                items: [
                    WallpaperItem(
                        id: "red_distortion_2",
                        name: "Red Distortion 2",
                        path: wallpaperPath("red_distortion_2.heic"),
                        gradientColors: [Color(red: 0.94, green: 0.12, blue: 0.38), Color(red: 0.65, green: 0.05, blue: 0.22)],
                        accentHue: 0.98
                    ),
                    WallpaperItem(
                        id: "red_distortion_1",
                        name: "Red Distortion 1",
                        path: wallpaperPath("red_distortion_1.heic"),
                        gradientColors: [Color(red: 0.96, green: 0.20, blue: 0.30), Color(red: 0.70, green: 0.08, blue: 0.25)],
                        accentHue: 0.96
                    ),
                    WallpaperItem(
                        id: "red_distortion_3",
                        name: "Red Distortion 3",
                        path: wallpaperPath("red_distortion_3.heic"),
                        gradientColors: [Color(red: 0.98, green: 0.30, blue: 0.25), Color(red: 0.50, green: 0.04, blue: 0.15)],
                        accentHue: 0.02
                    ),
                    WallpaperItem(
                        id: "red_distortion_4",
                        name: "Red Distortion 4",
                        path: wallpaperPath("red_distortion_4.heic"),
                        gradientColors: [Color(red: 0.90, green: 0.08, blue: 0.45), Color(red: 0.40, green: 0.02, blue: 0.20)],
                        accentHue: 0.92
                    ),
                    WallpaperItem(
                        id: "blue_distortion_1",
                        name: "Blue Distortion 1",
                        path: wallpaperPath("blue_distortion_1.heic"),
                        gradientColors: [Color(red: 0.12, green: 0.45, blue: 0.95), Color(red: 0.05, green: 0.15, blue: 0.60)],
                        accentHue: 0.60
                    ),
                    WallpaperItem(
                        id: "blue_distortion_2",
                        name: "Blue Distortion 2",
                        path: wallpaperPath("blue_distortion_2.heic"),
                        gradientColors: [Color(red: 0.20, green: 0.60, blue: 0.98), Color(red: 0.08, green: 0.25, blue: 0.70)],
                        accentHue: 0.58
                    )
                ]
            ),
            
            // Pack 2: Raycast 3D Geometry (3D Objects Only)
            WallpaperPack(
                id: "raycast_3d",
                name: "Raycast 3D Geometry",
                description: "Official 6K raytraced 3D glass geometries, liquid spheres & isometric studio cubes by Raycast.",
                items: [
                    WallpaperItem(
                        id: "blob_red",
                        name: "Blob Crimson",
                        path: wallpaperPath("blob-red.heic"),
                        gradientColors: [Color(red: 0.95, green: 0.20, blue: 0.35), Color(red: 0.50, green: 0.05, blue: 0.18)],
                        accentHue: 0.97
                    ),
                    WallpaperItem(
                        id: "blob_purple",
                        name: "Blob Nebula",
                        path: wallpaperPath("blob.heic"),
                        gradientColors: [Color(red: 0.65, green: 0.25, blue: 0.85), Color(red: 0.25, green: 0.08, blue: 0.45)],
                        accentHue: 0.80
                    ),
                    WallpaperItem(
                        id: "cube_prod",
                        name: "Cube Studio Red",
                        path: wallpaperPath("cube_prod.heic"),
                        gradientColors: [Color(red: 0.90, green: 0.35, blue: 0.25), Color(red: 0.45, green: 0.10, blue: 0.15)],
                        accentHue: 0.03
                    ),
                    WallpaperItem(
                        id: "loupe",
                        name: "Loupe Glass",
                        path: wallpaperPath("loupe.heic"),
                        gradientColors: [Color(red: 0.50, green: 0.30, blue: 0.80), Color(red: 0.15, green: 0.10, blue: 0.35)],
                        accentHue: 0.74
                    ),
                    WallpaperItem(
                        id: "raycast_logo",
                        name: "Raycast Red Logo",
                        path: wallpaperPath("raycast-logo.heic"),
                        gradientColors: [Color(red: 1.0, green: 0.30, blue: 0.30), Color(red: 0.40, green: 0.05, blue: 0.08)],
                        accentHue: 0.0
                    ),
                    WallpaperItem(
                        id: "glaze_1",
                        name: "Glaze Amber",
                        path: wallpaperPath("glaze_1.heic"),
                        gradientColors: [Color(red: 0.85, green: 0.45, blue: 0.30), Color(red: 0.35, green: 0.15, blue: 0.25)],
                        accentHue: 0.05
                    ),
                    WallpaperItem(
                        id: "glaze_2",
                        name: "Glaze Azure",
                        path: wallpaperPath("glaze_2.heic"),
                        gradientColors: [Color(red: 0.30, green: 0.65, blue: 0.85), Color(red: 0.12, green: 0.20, blue: 0.45)],
                        accentHue: 0.56
                    )
                ]
            ),
            
            // Pack 3: Raycast Minimal Mono & Noir (All Official 6K)
            WallpaperPack(
                id: "raycast_mono",
                name: "Raycast Minimal Mono",
                description: "Official 6K stealth dark graphite, titanium studio & halftone noir by Raycast.",
                items: [
                    WallpaperItem(
                        id: "mono_dark_distortion_1",
                        name: "Mono Dark 1",
                        path: wallpaperPath("mono_dark_distortion_1.heic"),
                        gradientColors: [Color(red: 0.25, green: 0.25, blue: 0.28), Color(red: 0.10, green: 0.10, blue: 0.12)],
                        accentHue: 0.0
                    ),
                    WallpaperItem(
                        id: "mono_dark_distortion_2",
                        name: "Mono Dark 2",
                        path: wallpaperPath("mono_dark_distortion_2.heic"),
                        gradientColors: [Color(red: 0.30, green: 0.30, blue: 0.34), Color(red: 0.12, green: 0.12, blue: 0.15)],
                        accentHue: 0.0
                    ),
                    WallpaperItem(
                        id: "cube_mono",
                        name: "Cube Mono",
                        path: wallpaperPath("cube_mono.heic"),
                        gradientColors: [Color(red: 0.35, green: 0.35, blue: 0.38), Color(red: 0.15, green: 0.15, blue: 0.18)],
                        accentHue: 0.0
                    ),
                    WallpaperItem(
                        id: "loupe_mono_dark",
                        name: "Loupe Noir",
                        path: wallpaperPath("loupe-mono-dark.heic"),
                        gradientColors: [Color(red: 0.28, green: 0.28, blue: 0.32), Color(red: 0.08, green: 0.08, blue: 0.10)],
                        accentHue: 0.0
                    ),
                    WallpaperItem(
                        id: "ascii_halftone",
                        name: "ASCII Halftone",
                        path: wallpaperPath("ascii_halftone.png"),
                        gradientColors: [Color(red: 0.20, green: 0.20, blue: 0.22), Color(red: 0.05, green: 0.05, blue: 0.06)],
                        accentHue: 0.0
                    ),
                    WallpaperItem(
                        id: "mono_light_distortion_1",
                        name: "Mono Light 1",
                        path: wallpaperPath("mono_light_distortion_1.heic"),
                        gradientColors: [Color(red: 0.85, green: 0.85, blue: 0.88), Color(red: 0.55, green: 0.55, blue: 0.60)],
                        accentHue: 0.0
                    ),
                    WallpaperItem(
                        id: "mono_light_distortion_2",
                        name: "Mono Light 2",
                        path: wallpaperPath("mono_light_distortion_2.heic"),
                        gradientColors: [Color(red: 0.90, green: 0.90, blue: 0.92), Color(red: 0.65, green: 0.65, blue: 0.70)],
                        accentHue: 0.0
                    ),
                    WallpaperItem(
                        id: "loupe_mono_light",
                        name: "Loupe Frost Light",
                        path: wallpaperPath("loupe-mono-light.heic"),
                        gradientColors: [Color(red: 0.92, green: 0.92, blue: 0.95), Color(red: 0.70, green: 0.70, blue: 0.75)],
                        accentHue: 0.0
                    )
                ]
            ),
            
            // Pack 5: Fine Art & Classical Masterpieces - Exactly 5 Masterpieces
            WallpaperPack(
                id: "classical_art",
                name: "Fine Art & Classics",
                description: "5 classical masterpieces: Friedrich, Klimt, Botticelli, Vermeer & Hopper.",
                items: [
                    WallpaperItem(
                        id: "art_wanderer_sea_fog",
                        name: "Wanderer above the Sea of Fog",
                        path: wallpaperPath("art/ARTWORK-wanderer-above-the-sea-of-fog.jpg"),
                        gradientColors: [Color(red: 0.35, green: 0.42, blue: 0.48), Color(red: 0.15, green: 0.20, blue: 0.25)],
                        accentHue: 0.58
                    ),
                    WallpaperItem(
                        id: "art_the_kiss",
                        name: "The Kiss - Gustav Klimt",
                        path: wallpaperPath("art/ARTWORK-the-kiss.jpg"),
                        gradientColors: [Color(red: 0.85, green: 0.68, blue: 0.25), Color(red: 0.45, green: 0.30, blue: 0.10)],
                        accentHue: 0.12
                    ),
                    WallpaperItem(
                        id: "art_birth_of_venus",
                        name: "The Birth of Venus - Botticelli",
                        path: wallpaperPath("art/birthOfVenus.jpg"),
                        gradientColors: [Color(red: 0.72, green: 0.60, blue: 0.48), Color(red: 0.35, green: 0.45, blue: 0.48)],
                        accentHue: 0.09
                    ),
                    WallpaperItem(
                        id: "art_girl_pearl_earring",
                        name: "Girl with a Pearl Earring - Vermeer",
                        path: wallpaperPath("art/ARTWORK-meisje-met-de-parel.jpg"),
                        gradientColors: [Color(red: 0.25, green: 0.38, blue: 0.52), Color(red: 0.12, green: 0.12, blue: 0.15)],
                        accentHue: 0.58
                    ),
                    WallpaperItem(
                        id: "art_nighthawks",
                        name: "Nighthawks - Edward Hopper",
                        path: wallpaperPath("art/ARTWORK-nighthawk.jpg"),
                        gradientColors: [Color(red: 0.18, green: 0.35, blue: 0.32), Color(red: 0.08, green: 0.14, blue: 0.16)],
                        accentHue: 0.46
                    )
                ]
            )
        ]
    }
}
