// swift-tools-version: 5.9
// Copyright (c) Experian, 2026. All rights reserved.
import PackageDescription

let package = Package(
    name: "ModularSDK",
    platforms: [.iOS(.v13)],

    products: [
        .library(
            name: "ModularSDK",
            type: .dynamic,
            targets: ["ModularSDK"]
        ),
        
        .library(name: "Collector",
                 targets: ["Collector"]),
        
        .library(name: "DICollector",
                     targets: ["Core"]),
    ],
    dependencies: [],
    targets: [

        .target(
            name: "ModularSDK",
            dependencies: []
        ),
        
        .testTarget(
            name: "ModularSDKTests",
            dependencies: ["ModularSDK", "Core"],
            path: "Tests/ModularSDKTests/"
        ),
        
        .target(name: "Core", path: "Sources/Core/"),
        
        // MARK: - Collectors (UDI / DI)
        .target(
            name: "Collector",
            dependencies: ["Core", "UDI"]),
        
//        .target(name: "DICollector",
//                dependencies: ["Core", "DeviceInsight"]),
        
        // MARK: - Binary targets
//        .binaryTarget(name: "DeviceInsight", path: "Sources/Binaries/DeviceInsight.xcframework"),
        
        .binaryTarget(
            name: "UDI",
            url: "https://github.com/udi-collectors/udi-collector-ios/releases/download/1.3.0/udi-collector-ios-xcframework-1.3.0.zip",
            checksum: "7adeb357f0f29be739ee6f88c0d231f5d27b420df7d3843661fce3456c8e4bd9"
        ),
    ]
)
