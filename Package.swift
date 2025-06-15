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
                "README.md",
                "README_GITHUB_SYNC.md",
                "Info.plist",
                "build_app.sh",
                "create_dmg.sh",
                "sync_to_github.sh",
                "Assets/",
                "Archives/",
                "GoldPriceFeatures.md",
                ".git/",
                ".gitignore",
                ".DS_Store",
                ".cursor/",
                ".vscode/",
                "*.dmg"
            ]
        )
    ]
)