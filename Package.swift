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
                "github_sync_example.md",
                "Info.plist",
                "build_app.sh",
                "create_dmg.sh",
                "sync_to_github.sh",
                "sync_to_github_auto.sh",
                "Assets/",
                "Archives/",
                "GoldPriceFeatures.md",
                ".git/",
                ".DS_Store",
                ".cursor/",
                ".vscode/",
                "*.dmg"
            ]
        )
    ]
)