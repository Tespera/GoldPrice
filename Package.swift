// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "GoldPrice",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "GoldPrice", targets: ["GoldPrice"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GoldPrice",
            dependencies: [],
            path: ".",
            exclude: [
                "Info.plist",
                "Assets/",
                "Archives/",
                ".git/",
                ".DS_Store",
                ".cursor/",
                ".vscode/",
                "*.dmg",
                "*.sh",
                "*.md"
            ]
        )
    ]
)