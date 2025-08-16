// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DanmuFrequency",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "DanmuAnalyzer",
            targets: ["DanmuAnalyzer"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "DanmuAnalyzer",
            path: ".",
            sources: [
                "MainApp.swift",
                "Constants.swift",
                "Models.swift",
                "NetworkModels.swift",
                "Utilities.swift",
                "ErrorHandler.swift",
                "XMLDanmakuParser.swift",
                "NetworkManager.swift",
                "SMBDiscoveryManager.swift",
                "SMBConfigurationManager.swift",
                "ScheduleConfigurationManager.swift",
                "AddSMBConfigurationView.swift",
                "ActivityManager.swift",
            ]
        ),
    ]
)
