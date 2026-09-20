// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotskyApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NotskyApp",
            targets: ["NotskyApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "NotskyApp",
            path: "Sources/NotskyApp"
        )
    ]
)
