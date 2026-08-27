//  Copyright (c) Experian, 2026. All rights reserved.
//
//  DeviceInsightCollector.swift
//  ModularSDK
//
//

@_exported import Core
import Foundation

#if canImport(DeviceInsight)
import DeviceInsight
#endif


/// Contract defining a Device Insight data collector.
///
/// `DeviceInsightCollecting` provides both synchronous and asynchronous collection APIs
/// that return a lightweight tuple result. This protocol is adopted by the
/// Device Insight collector implementation.
public protocol DeviceInsightCollecting {

    /// Performs data collection synchronously.
    ///
    /// - Returns: A tuple containing:
    ///   - `String?`: The collected payload, if available.
    ///   - `Int?`: An optional numeric identifier or status code associated with the collection.
    func collect() -> (String?, Int?)

    /// Performs data collection asynchronously.
    ///
    /// - Returns: A tuple containing:
    ///   - `String?`: The collected payload, if available.
    ///   - `Int?`: An optional numeric identifier or status code associated with the collection.
    func collectAsync() async -> (String?, Int?)
}

/// A `Module` implementation that integrates the **Device Insight** collector
/// into the Modular SDK orchestration flow.
///
/// This module is responsible for triggering data collection using
/// `DeviceInsightCollector` and exposing the result through `endCollect()`.
/// It supports the asynchronous collection path via `startCollect()`.
///
/// This module accepts no runtime configuration (`Config == NoConfig`).
public final class DeviceInsightCollectorModule: Module {

    public typealias Config = NoConfig
    
    /// Unique key used to identify this module's collected output.
    ///
    /// This key is used by `ModuleCollection` to store and retrieve
    /// the `DeviceInsightResponse` produced by this module.
    public var key = ModuleKeys.deviceInsight

    /// Version of the `deviceinsight-collector-ios` engine this module wraps.
    public func version() -> String? { CollectorVersions.deviceInsight }

    /// Holds the most recent collected payload (if any) for later retrieval
    /// by `endCollect()`.
    ///
    /// The value is set during `startCollect()` and read in `endCollect()`.
    var payload: DeviceInsightResponse?

    /// Protects payload ownership across superseded collection runs.
    private let collectionLock = NSLock()
    private var collectionGeneration = 0

    /// Underlying Device Insight collector instance used to perform the actual
    /// data acquisition.
    private let deviceInsightCollector: DeviceInsightCollecting

    /// Creates a new instance of `DeviceInsightCollectorModule`.
    ///
    /// The initializer is intentionally lightweight; any resource preparation
    /// should be performed in the lifecycle methods (`initialize`, `loadCollector`,
    /// etc.) if/when needed.
    public init(deviceInsightCollector: DeviceInsightCollecting = DeviceInsightCollector()) {
        self.deviceInsightCollector = deviceInsightCollector
    }

    /// Starts asynchronous data collection using the underlying
    /// `DeviceInsightCollector`.
    ///
    /// On success, the resulting payload is cached in `payload` so it can be
    /// returned by `endCollect()`. The default error code is set to an empty
    /// string (`""`) when no error is reported by the collector.
    ///
    /// - Throws: Rethrows any error thrown by the underlying collector.
    public func startCollect() async throws {
        let generation = beginCollection()
        let result = await deviceInsightCollector.collectAsync()
        commit(result, generation: generation)
    }

    /// Starts synchronous DeviceInsight data collection.
    public func startCollectSync() throws {
        let generation = beginCollection()
        let result = deviceInsightCollector.collect()
        commit(result, generation: generation)
    }

    /// Ends the collection phase and returns the previously collected payload.
    ///
    /// - Returns: `nil` when no payload has been collected, otherwise
    ///   `.success` carrying the `DeviceInsightResponse` captured during `startCollect()`.
    public func endCollect() -> ModuleResult<DeviceInsightResponse>? {
        collectionLock.lock()
        defer { collectionLock.unlock() }
        guard let collected = payload else { return nil }
        return .success(collected)
    }
    
    /// No-op: Device Insight accepts no runtime configuration.
    public func configure(_: NoConfig) async -> ModuleResult<Void> {
        .success(())
    }

    private func beginCollection() -> Int {
        collectionLock.lock()
        collectionGeneration += 1
        let generation = collectionGeneration
        collectionLock.unlock()
        return generation
    }

    private func commit(_ result: DeviceInsightResponse, generation: Int) {
        collectionLock.lock()
        defer { collectionLock.unlock() }
        guard generation == collectionGeneration, !Task.isCancelled else { return }
        payload = result
    }
}

#if canImport(DeviceInsight)
/// C-callable entry point for dynamically loading the Device Insight module.
///
/// The orchestrator can invoke this symbol to register the `DeviceInsightCollectorModule`
/// at runtime without requiring direct linkage.
///
/// Symbol name: `load_device_insight_collector`
@_cdecl("load_device_insight_collector")
public func loadDeviceInsightModule() {
    ModularOrchestrator.shared.register(DeviceInsightCollectorModule())
}

extension DeviceInsightCollector: DeviceInsightCollecting { }
#endif
