//  Copyright (c) Experian, 2026. All rights reserved.
//
//  DeviceIntelligenceCollector.swift
//  ModularSDK
//
//

@_exported import Core
import Foundation

#if canImport(UDI)
import UDI
#endif

/// Contract defining the collection behavior for DeviceIntelligence data providers.
///
/// `DeviceIntelligenceCollecting` supports both asynchronous and synchronous execution flows,
/// optional preloading of resources, and runtime configuration.
/// Implementations may choose which execution model to use based on their context.
public protocol DeviceIntelligenceCollecting {

    /// Loads or preloads resources required for DeviceIntelligence collection asynchronously.
    ///
    /// This method is typically used to prepare network, disk, or in‑memory
    /// resources before `collect()` is invoked.
    func loadPayload() async

    /// Loads or preloads resources required for DeviceIntelligence collection synchronously.
    ///
    /// Use this method in environments where asynchronous execution
    /// is not available or not desired.
    ///
    /// - Throws: An error if resource loading fails.
    func loadPayloadSync() throws

    /// Performs DeviceIntelligence data collection asynchronously.
    ///
    /// - Returns: A `DeviceIntelligenceResponse` containing the collected data.
    /// - Throws: An error if the collection process fails.
    func collect() async throws -> DeviceIntelligenceResponse

    /// Performs DeviceIntelligence data collection synchronously.
    ///
    /// - Returns: A `DeviceIntelligenceResponse` containing the collected data.
    /// - Throws: An error if the collection process fails.
    func collectSync() throws -> DeviceIntelligenceResponse

    /// Applies runtime configuration to the collector.
    ///
    /// This is commonly used to configure remote endpoints, feature flags,
    /// or environment‑specific settings prior to collection.
    ///
    /// - Parameter configURL: A string representing the configuration endpoint or location.
    func setConfig(configURL: String) async
}

/// A module responsible for orchestrating configuration and
/// two-phase collection of the DeviceIntelligence SDK.
///
/// Responsibilities:
/// - Acts as a bridge between the modular SDK and the vendor `UDICollector` type.
/// - Exposes both async and synchronous collection APIs.
/// - Stores the collected payload temporarily until `endCollect()` is called.
/// - Registers itself into the modular registry when dynamically loaded.
///
/// Collection Lifecycle:
/// 1. `initialize()` / `loadCollector()` – Prepares internal payload structures.
/// 2. `startCollect()` / `startCollectSync()` – Starts the collection process.
/// 3. `endCollect()` – Returns the collected payload.
///
/// State & Preconditions:
/// - `configure(configure:)` must be called before starting collection.
/// - `startCollect()` or `startCollectSync()` must be called before `endCollect()`.
///
/// Threading:
/// - Async APIs leverage Swift Concurrency.
/// - Sync APIs are provided for environments where async is not available.
///
/// - Important: Calling `endCollect()` before a successful collection
///   returns `nil` rather than failing. No payload is reported and the
///   module contributes no entry to `ModuleCollection`.
public final class DeviceIntelligenceCollectorModule: Module {
    
    public var key: ModuleKey<DeviceIntelligenceResponse> = ModuleKeys.deviceIntelligence

    /// Version of the DeviceIntelligence engine this module wraps.
    public func version() -> String? { CollectorVersions.deviceIntelligence }

    /// Cached payload returned by the DeviceIntelligence collector.
    private var payload: DeviceIntelligenceResponse?

    /// Protects payload ownership across superseded collection runs.
    private let collectionLock = NSLock()
    private var collectionGeneration = 0
    
    /// Underlying DeviceIntelligence collector instance.
    private let deviceIntelligenceCollector: DeviceIntelligenceCollecting
    
    /// Creates a new `DeviceIntelligenceCollectorModule`.
    ///
    /// The collector dependency is injectable for focused adapter tests.
    public init(deviceIntelligenceCollector: DeviceIntelligenceCollecting = UDICollector()) {
        self.deviceIntelligenceCollector = deviceIntelligenceCollector
    }
    
    /// Initializes the collector asynchronously.
    ///
    /// Typically used as a preloading step before starting collection.
    public func initialize() async {
        await deviceIntelligenceCollector.loadPayload()
    }
    
    /// Starts asynchronous data collection.
    ///
    /// Behavior:
    /// - Invokes the underlying DeviceIntelligence collector.
    /// - Stores the result internally until `endCollect()` is called.
    ///
    public func startCollect() async throws {
        let generation = beginCollection()
        let result = try await deviceIntelligenceCollector.collect()
        commit(result, generation: generation)
    }
    
    /// Starts synchronous data collection.
    ///
    /// Behavior:
    /// - Invokes the synchronous DeviceIntelligence collection API.
    /// - Stores the result internally until `endCollect()` is called.
    ///
    public func startCollectSync() throws {
        let generation = beginCollection()
        let result = try deviceIntelligenceCollector.collectSync()
        commit(result, generation: generation)
    }
    
    /// Loads the collector asynchronously without starting collection.
    ///
    /// Useful when preloading resources is required.
    public func loadCollector() async {
        await deviceIntelligenceCollector.loadPayload()
    }
    
    /// Loads the collector synchronously without starting collection.
    public func loadCollectorSync() throws {
        try deviceIntelligenceCollector.loadPayloadSync()
    }
    
    /// Ends the collection process and returns the collected payload.
    ///
    /// - Returns: `nil` if no payload was previously collected,
    ///   otherwise `.success` carrying the collected `DeviceIntelligenceResponse`.
    ///
    /// - Important: `startCollect()` or `startCollectSync()` must be
    ///   called before invoking this method.
    public func endCollect() -> ModuleResult<DeviceIntelligenceResponse>? {
        collectionLock.lock()
        defer { collectionLock.unlock() }
        guard let collected = payload else { return nil }
        return .success(collected)
    }
    
    /// Configures the underlying DeviceIntelligence collector.
    ///
    /// - Parameter configure: A typed configuration builder expected
    ///   to be `DeviceIntelligenceConfig`.
    ///
    /// - Returns: `.success(())` once the URL has been handed to the collector.
    ///
    /// Preconditions:
    /// - A valid DeviceIntelligence configuration must be provided.
    /// - A valid configuration URL must be provided.
    public func configure(_ configure: DeviceIntelligenceConfig) async -> ModuleResult<Void> {
        let configURL = configure.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: configURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            return .failure(.invalidConfig(moduleKey: key.name))
        }
        await deviceIntelligenceCollector.setConfig(configURL: configURL)
        return .success(())
    }

    private func beginCollection() -> Int {
        collectionLock.lock()
        collectionGeneration += 1
        let generation = collectionGeneration
        collectionLock.unlock()
        return generation
    }

    private func commit(_ result: DeviceIntelligenceResponse, generation: Int) {
        collectionLock.lock()
        defer { collectionLock.unlock() }
        guard generation == collectionGeneration, !Task.isCancelled else { return }
        payload = result
    }
}

#if canImport(UDI)

/// C entry point used for dynamic module loading.
///
/// When invoked, registers `DeviceIntelligenceCollectorModule`
/// into the shared orchestrator.
@_cdecl("load_device_intelligence_collector")
public func loadDeviceIntelligenceModule() {
    ModularOrchestrator.shared.register(DeviceIntelligenceCollectorModule())
}

#endif

// DeviceIntelligence is currently delivered by the vendor module and type named `DeviceIntelligence`.
extension UDICollector: DeviceIntelligenceCollecting { }
