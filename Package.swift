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
    platforms: [.iOS(.v15)],

    products: [
        .library(
            name: "ModularSDK",
            type: .dynamic,
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
            dependencies: []
        ),
        
        .target(name: "Core", path: "Sources/Core/"),
        
        // MARK: - Collectors (UDI / DI)
        .target(
            name: "DeviceIntelligenceCollector",
            dependencies: ["Core", "UDI"]),
        
        .target(
            name: "DeviceInsightCollector",
            dependencies: ["Core", "DeviceInsight"]),

        // MARK: - Binary targets
        .binaryTarget(
            name: "DeviceInsight",
            url: "https://github.com/udi-collectors/deviceinsight-collector-ios/releases/download/8.0.9/deviceinsight-collector-ios-xcframework-8.0.9.zip",
            checksum: "1af16d7e2027c6980d7e88a34f7e6157fa7f77013d0d865704038bef1cfdf415"
        ),
        
        .binaryTarget(
            name: "UDI",
            url: "https://github.com/udi-collectors/udi-collector-ios/releases/download/9.4.0/udi-collector-ios-xcframework-9.4.0.zip",
            checksum: "e89bf832eccbde2cf9b56ccf595344ab5547cae009caa287b53456e15c022e56"
        ),
    ]
)

if hasModularSDKTests {
    package.targets.append(
        .testTarget(
            name: "ModularSDKTests",
            dependencies: ["ModularSDK", "Core"],
            path: modularSDKTestsPath
        )
    )
}
