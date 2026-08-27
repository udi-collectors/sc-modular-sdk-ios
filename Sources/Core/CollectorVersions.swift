//  Copyright (c) Experian, 2026. All rights reserved.
//
//  CollectorVersions.swift
//  ModularSDK
//
//

/// Versions of the closed-source collection engines the SDK wraps.
///
/// These are the versions of the `binaryTarget` xcframeworks declared in
/// `Package.swift` — not the version of the modular SDK itself. Modules surface
/// them through `Module.version()`, so consumers can report which engine they are
/// actually running (see `ModularOrchestrator.version(for:)`).
///
/// - Important: These constants and the `binaryTarget` URLs in `Package.swift`
///   must state the same version. The vendor xcframeworks expose no runtime
///   version symbol, so nothing at compile time links the two. `build_all.sh`
///   asserts they agree (`check_collector_versions`) and fails the build on
///   drift — bump both together when a collector is upgraded.
public enum CollectorVersions {

    /// Version of the `udi-collector-ios` xcframework wrapped by
    /// `DeviceIntelligenceCollector`.
    public static let deviceIntelligence = "9.4.0"

    /// Version of the `deviceinsight-collector-ios` xcframework wrapped by
    /// `DeviceInsightCollector`.
    public static let deviceInsight = "8.0.3"
}
