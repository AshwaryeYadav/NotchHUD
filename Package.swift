// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NotchHUD",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "NotchHUD",
            path: ".",
            sources: [
                "NotchHUDApp.swift",
                "NotchHUDWindowController.swift",
                "NotchHUDView.swift",
                "NowPlayingManager.swift"
            ]
        )
    ]
)
