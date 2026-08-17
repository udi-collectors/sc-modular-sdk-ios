//  Copyright (c) Experian, 2026. All rights reserved.
//
//  DeviceInsightCollector.swift
//  ModularSDK
//
//

@_exported import Core

#if canImport(DeviceInsight)
import DeviceInsight
#endif


/// Contract defining a Device Insight data collector.
///
/// `DICollecting` provides both synchronous and asynchronous collection APIs
/// that return a lightweight tuple result. This protocol is adopted by the
/// Device Insight collector implementation.
public protocol DICollecting {

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
public final class DICollectorModule: Module {
    
    /// Unique key used to identify this module's collected output.
    ///
    /// This key is used by `ModuleCollection` to store and retrieve
    /// the `DIResponse` produced by this module.
    public var key = ModuleKeys.di

    /// Holds the most recent collected payload (if any) for later retrieval
    /// by `endCollect()`.
    ///
    /// The value is set during `startCollect()` and read in `endCollect()`.
    var payload: DIResponse?

    /// Underlying Device Insight collector instance used to perform the actual
    /// data acquisition.
    private let diCollector: DICollecting

    /// Creates a new instance of `DICollectorModule`.
    ///
    /// The initializer is intentionally lightweight; any resource preparation
    /// should be performed in the lifecycle methods (`initialize`, `loadCollector`,
    /// etc.) if/when needed.
    public init(diCollector: DICollecting = DeviceInsightCollector()) {
        self.diCollector = diCollector
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
        self.payload = await diCollector.collectAsync()
    }

    /// Starts synchronous data collection (not currently implemented).
    ///
    /// This method is defined to satisfy the `Module` contract. If synchronous
    /// collection is required in the future, implement it here. Otherwise, this
    /// can remain a no-op or throw a `notSupported` error depending on your
    /// SDK design.
    public func startCollectSync() throws {
        self.payload = diCollector.collect()
    }

    /// Ends the collection phase and returns the previously collected payload.
    ///
    /// - Returns: `nil` when no payload has been collected, otherwise
    ///   `.success` carrying the `DIResponse` captured during `startCollect()`.
    public func endCollect() -> ModuleResult<DIResponse>? {
        guard let payload = payload else { return nil }
        return .success(payload)
    }
    
    /// This module takes no runtime configuration.
    public func configure(_ configure: Void) async -> ModuleResult<Void> {
        return .success(())
    }
}

#if canImport(DeviceInsight)
/// C-callable entry point for dynamically loading the Device Insight module.
///
/// The orchestrator can invoke this symbol to register the `DICollectorModule`
/// at runtime without requiring direct linkage.
///
/// Symbol name: `load_di_collector`
@_cdecl("load_di_collector")
public func loadDiModule() {
    ModularOrchestrator.shared.register(DICollectorModule())
}

extension DeviceInsightCollector: DICollecting { }
#endif
