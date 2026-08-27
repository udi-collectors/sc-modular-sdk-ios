// swift-tools-version: 5.9
// Copyright (c) Experian, 2026. All rights reserved.
import PackageDescription
import Foundation

// The published full-sdk artifact ships Package.swift + Sources only: the test
// sources are internal and the zip is mirrored to a public GitHub repo. SwiftPM
// refuses to load a manifest whose target path is absent ("invalid custom path
// ... for target ModularSDKTests"), so the test target has to be declared only
// when the directory is actually there. In this repo it always is, so local and
// CI builds keep running the tests unchanged.
let modularSDKTestsPath = "Tests/ModularSDKTests/"
let hasModularSDKTests = FileManager.default.fileExists(
    atPath: "\(Context.packageDirectory)/\(modularSDKTestsPath)"
)

var package = Package(
    name: "ModularSDK",
    // 15.6, not 15.0: the DeviceInsight binary target is built with a 15.6
    // deployment target (`minos 15.6` in both slices), so a consumer below that
    // would resolve the package and then link a dylib built for a newer OS.
    // Stating the real floor makes that a resolve-time error, not a link warning.
    platforms: [.iOS("15.6")],

    products: [
        .library(
            name: "ModularSDK",
            type: .static,
            targets: ["ModularSDK"]
        ),
        
        .library(name: "DeviceIntelligenceCollector",
                 targets: ["DeviceIntelligenceCollector"]),
        
        .library(name: "DeviceInsightCollector",
                 targets: ["DeviceInsightCollector"]),
    ],
    dependencies: [],
    targets: [

        .target(
            name: "ModularSDK",
            dependencies: ["Core"]
        ),
        
        .target(name: "Core", path: "Sources/Core/"),
        
        // MARK: - Collectors (DeviceIntelligence / DeviceInsight)
        .target(
            name: "DeviceIntelligenceCollector",
            dependencies: ["Core", "UDI"]),
        
        .target(
            name: "DeviceInsightCollector",
            dependencies: ["Core", "DeviceInsight"]),

        // MARK: - Binary targets
        .binaryTarget(
            name: "DeviceInsight",
            url: "https://github.com/experian-collectors/deviceinsight-ios/releases/download/8.0.3/deviceinsight-collector-ios-xcframework-8.0.3.zip",
            checksum: "59bfb1db622d3ca7f7ab781da6883a8fc7593a2cb5de5d2c6725cca252709a64"
        ),
        
        .binaryTarget(
            name: "UDI",
            url: "https://github.com/experian-collectors/deviceintelligence-ios/releases/download/9.4.0/deviceintelligence-collector-ios-xcframework-9.4.0.zip",
            checksum: "e89bf832eccbde2cf9b56ccf595344ab5547cae009caa287b53456e15c022e56"
        ),
    ]
)

if hasModularSDKTests {
    package.targets.append(
        .testTarget(
            name: "ModularSDKTests",
            dependencies: [
                "ModularSDK",
                "Core",
                "DeviceIntelligenceCollector",
                "DeviceInsightCollector"
            ],
            path: modularSDKTestsPath
        )
    )
}
