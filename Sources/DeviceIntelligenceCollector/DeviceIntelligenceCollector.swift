//  Copyright (c) Experian, 2026. All rights reserved.
//
//  DeviceIntelligenceCollector.swift
//  ModularSDK
//
//

@_exported import Core

#if canImport(UDI)
import UDI
import Foundation
#endif

/// Contract defining the collection behavior for UDI data providers.
///
/// `UDICollecting` supports both asynchronous and synchronous execution flows,
/// optional preloading of resources, and runtime configuration.
/// Implementations may choose which execution model to use based on their context.
public protocol UDICollecting {

    /// Loads or preloads resources required for UDI collection asynchronously.
    ///
    /// This method is typically used to prepare network, disk, or in‑memory
    /// resources before `collect()` is invoked.
    func loadPayload() async

    /// Loads or preloads resources required for UDI collection synchronously.
    ///
    /// Use this method in environments where asynchronous execution
    /// is not available or not desired.
    ///
    /// - Throws: An error if resource loading fails.
    func loadPayloadSync() throws

    /// Performs UDI data collection asynchronously.
    ///
    /// - Returns: A `UDIResponse` containing the collected data.
    /// - Throws: An error if the collection process fails.
    func collect() async throws -> UDIResponse

    /// Performs UDI data collection synchronously.
    ///
    /// - Returns: A `UDIResponse` containing the collected data.
    /// - Throws: An error if the collection process fails.
    func collectSync() throws -> UDIResponse

    /// Applies runtime configuration to the collector.
    ///
    /// This is commonly used to configure remote endpoints, feature flags,
    /// or environment‑specific settings prior to collection.
    ///
    /// - Parameter configURL: A string representing the configuration endpoint or location.
    func setConfig(configURL: String) async
}

/// A module responsible for orchestrating configuration and
/// two-phase collection of the UDI SDK.
///
/// Responsibilities:
/// - Acts as a bridge between the modular SDK and `UDICollector`.
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
///   results in a runtime failure.
public final class CollectorModule: Module {
    
    public var key = ModuleKeys.udi
    
    /// Cached payload returned by the UDI collector.
    private var payload: UDIResponse?
    
    /// Underlying UDI collector instance.
    private let udiCollector: UDICollecting
    
    /// Creates a new `CollectorModule`.
    ///
    /// This initializer is used to test cases
    public init(udiCollector: UDICollecting = UDICollector()) {
        self.udiCollector = udiCollector
    }
    
    /// Initializes the collector asynchronously.
    ///
    /// Typically used as a preloading step before starting collection.
    public func initialize() async {
        await udiCollector.loadPayload()
    }
    
    /// Starts asynchronous data collection.
    ///
    /// Behavior:
    /// - Invokes the underlying `UDICollector.collect()`.
    /// - Stores the result internally until `endCollect()` is called.
    ///
    public func startCollect() async throws {
        payload = try await udiCollector.collect()
    }
    
    /// Starts synchronous data collection.
    ///
    /// Behavior:
    /// - Invokes `UDICollector.collectSync()`.
    /// - Stores the result internally until `endCollect()` is called.
    ///
    public func startCollectSync() throws {
        payload = try udiCollector.collectSync()
    }
    
    /// Loads the collector asynchronously without starting collection.
    ///
    /// Useful when preloading resources is required.
    public func loadCollector() async {
        await udiCollector.loadPayload()
    }
    
    /// Loads the collector synchronously without starting collection.
    public func loadCollectorSync() throws {
        try udiCollector.loadPayloadSync()
    }
    
    /// Ends the collection process and returns the collected payload.
    ///
    /// - Returns: `nil` if no payload was previously collected,
    ///   otherwise `.success` carrying the collected `UDIResponse`.
    ///
    /// - Important: `startCollect()` or `startCollectSync()` must be
    ///   called before invoking this method.
    public func endCollect() -> ModuleResult<UDIResponse>? {
        guard let payload = payload else { return nil }
        return .success(payload)
    }
    
    /// Configures the underlying UDI collector.
    ///
    /// - Parameter configure: A typed configuration builder expected
    ///   to be `UDIConfigureBuilder`.
    ///
    /// - Returns: `.success(())` once the URL has been handed to the collector.
    ///
    /// Preconditions:
    /// - The builder must be of type `UDIConfigureBuilder`.
    /// - A valid configuration URL must be provided.
    public func configure(_ configure: UDIConfig) async -> ModuleResult<Void> {
        await udiCollector.setConfig(configURL: configure.url)
        return .success(())
    }
}

#if canImport(UDI)

/// C entry point used for dynamic module loading.
///
/// When invoked, registers `CollectorModule`
/// into the shared `ModulesRegistry`.
@_cdecl("load_collector")
public func loadModule() {
    ModularOrchestrator.shared.register(CollectorModule())
}

#endif

extension UDICollector : UDICollecting { }
