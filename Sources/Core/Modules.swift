//  Copyright (c) Experian, 2026. All rights reserved.
//
//  Modules.swift
//  ModularSDK
//
//

/// Identifies the available module categories supported by the SDK.
///
/// Modules use this enum to declare their role within the modular
/// architecture, allowing the orchestrator to group and reason
/// about different module behaviors.
public enum Modules: Hashable {
    
    /// Default or unspecified module category.
    case `default`
    
    /// Standard UDI collector module.
    case collector
    
    /// Device Insight collector module.
    case diCollector
}

/// Contract that every dynamic module must conform to
/// in order to integrate with `ModularOrchestrator`.
///
/// Responsibilities:
/// - Defines a common lifecycle for modular SDK components.
/// - Supports both asynchronous and synchronous execution models.
/// - Allows dynamic configuration and two-phase data collection.
///
/// Lifecycle:
/// 1. `initialize()` – Optional asynchronous setup or warm-up phase.
/// 2. `loadCollector()` / `loadCollectorSync()` – Optional resource preparation.
/// 3. `startCollect()` / `startCollectSync()` – Begins data collection.
/// 4. `endCollect()` – Produces the collected result.
/// 5. `configure(configure:)` – Applies runtime configuration.
///
/// Threading:
/// - Asynchronous APIs leverage Swift Concurrency.
/// - Synchronous APIs are provided for legacy or constrained environments.
///
/// - Important:
///   - Either `startCollect()` or `startCollectSync()` should be called
///     before invoking `endCollect()`.
///   - Not all lifecycle methods must perform work; default or no-op
///     behavior may be appropriate for some modules.
public protocol Module {
    
    /// The type of value produced by this module.
    ///
    /// This associated type is returned by `endCollect()` and
    /// is used to strongly type module results.
    associatedtype Output
    associatedtype Config
    
    /// The unique key used to identify this module's output.
    ///
    /// This key is used when inserting values into
    /// `ModuleCollection` during aggregation.
    var key: ModuleKey<Output> { get }
    
    /// Performs asynchronous initialization or setup.
    ///
    /// This method may be used to perform lightweight
    /// preparation work before collection begins.
    func initialize() async
    
    /// Starts asynchronous data collection.
    ///
    /// - Throws: An error if the collection process fails.
    func startCollect() async throws
    
    /// Starts synchronous data collection.
    ///
    /// - Throws: An error if the collection process fails.
    func startCollectSync() throws
    
    /// Loads or preloads collector resources asynchronously.
    ///
    /// This method is typically used to prepare resources
    /// needed prior to collection.
    func loadCollector() async
    
    /// Loads or preloads collector resources synchronously.
    ///
    /// - Throws: An error if resource loading fails.
    func loadCollectorSync() throws
    
    /// Ends the collection phase and returns the collected result.
    ///
    /// - Returns: `nil` if the module produced nothing, `.success` carrying
    ///   the collected output, or `.failure` if the module tried and failed.
    func endCollect() -> ModuleResult<Output>?
    
    /// Applies runtime configuration to the module.
    ///
    /// - Parameter configure: A builder containing configuration
    ///   values provided at runtime.
    /// - Returns: `.success(())` on success, or `.failure` with a
    ///   `ModuleError` describing why configuration failed.
    func configure(_ configure: Config) async -> ModuleResult<Void>
}


/// Provides default (no‑op) implementations for optional `Module` methods.
///
/// These implementations allow conforming types to omit methods that are not
/// relevant to their behavior, without requiring explicit empty method bodies.
/// Modules may override any of these defaults to provide custom logic.
public extension Module {

    /// Loads or preloads collector resources asynchronously.
    ///
    /// The default implementation performs no work.
    /// Override this method in modules that need to prepare resources
    /// asynchronously before data collection begins.
    func loadCollector() async {}

    /// Loads collector resources synchronously.
    ///
    /// The default implementation performs no work.
    /// Override this method when the module requires synchronous preparation
    /// of resources prior to collection.
    func loadCollectorSync() throws {}

    /// Performs the module's initialization steps.
    ///
    /// The default implementation performs no work.
    /// Override this method to execute asynchronous setup operations needed
    /// before collection or configuration occurs.
    func initialize() async {}
}
