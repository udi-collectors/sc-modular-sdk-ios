//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModularOrchestrator.swift
//  ModularSDK
//
//

import Foundation

/// Configuration object used to initialize or customize DeviceIntelligence collection.
///
/// `DeviceIntelligenceConfig` encapsulates configuration values required by DeviceIntelligence
/// modules, such as remote endpoints or environment-specific settings.
public struct DeviceIntelligenceConfig {

    /// The URL used to configure the DeviceIntelligence collector.
    ///
    /// This value typically represents a remote endpoint or configuration
    /// resource required during the collection process.
    public var url: String

    /// Creates a new DeviceIntelligence configuration instance.
    ///
    /// - Parameter url: The configuration URL to be used by the DeviceIntelligence collector.
    public init(url: String) {
        self.url = url
    }
}

/// Marker type for modules that accept no runtime configuration (e.g. Device Insight).
public struct NoConfig {}

public typealias DeviceInsightResponse = (String?, Int?)
public typealias DeviceIntelligenceResponse = (payload: String?, transactionId: String?)

/// Well-known keys used to retrieve typed module results
/// from a `ModuleCollection`.
public enum ModuleKeys {
    public static let deviceInsight = ModuleKey<DeviceInsightResponse>("deviceInsight")
    public static let deviceIntelligence = ConfigurableModuleKey<
        DeviceIntelligenceResponse,
        DeviceIntelligenceConfig
    >("deviceIntelligence")
}

private actor LifecycleOperationGate {
    private var isRunning = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard isRunning else {
            isRunning = true
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        guard !waiters.isEmpty else {
            isRunning = false
            return
        }
        waiters.removeFirst().resume()
    }
}

/// Central orchestrator responsible for coordinating
/// all registered modules within the SDK.
///
/// Responsibilities:
/// - Maintains a registry of dynamically registered modules.
/// - Propagates lifecycle events to all modules.
/// - Aggregates collection results into a unified structure.
///
/// Architecture:
/// - Singleton-based access via `shared`.
/// - Modules are typically registered at runtime.
///
/// Execution Model:
/// - Lifecycle methods are executed sequentially,
///   following module registration order.
/// - Errors thrown by individual modules are caught and
///   do not stop orchestration (best‑effort execution).
///
/// Threading:
/// - Public async lifecycle operations are serialized internally.
/// - Synchronous lifecycle methods execute immediately on the calling thread
///   and must not overlap asynchronous lifecycle work.
/// - Registry and bootstrap state are protected by locks.
///
/// - Important: Module execution order follows the
///   registration order and is not otherwise enforced.
public final class ModularOrchestrator {

    /// Shared singleton instance.
    public static let shared = ModularOrchestrator()

    /// Private initializer enforcing singleton usage.
    private init() {
        // All runtime state starts empty and is populated through registration.
    }

    /// Internal list of registered modules.
    ///
    /// Modules are executed in registration order.
    private var modules: [AnyModule] = []
    private let stateLock = NSRecursiveLock()

    /// Known collector symbols that failed dynamic loading.
    private var unavailableSymbols: Set<String> = []

    /// Serializes public async lifecycle entry points.
    private let lifecycleGate = LifecycleOperationGate()

    /// Registers a new module for orchestration.
    ///
    /// - Parameter module: A concrete type conforming to `Module`.
    ///
    /// Once registered, the module participates in all lifecycle
    /// operations propagated by the orchestrator. A module whose key
    /// instance is already registered is skipped; the first registration wins.
    public func register<M: Module>(_ module: M) {
        stateLock.lock()
        defer { stateLock.unlock() }
        let newKey = module.key as AnyObject
        if modules.contains(where: { ($0.key as AnyObject) === newKey }) {
            Logger.log("Skipping register: duplicate module key \(module.key.name)", type: .default)
            return
        }
        modules.append(ModuleBox(module))
    }

    func recordUnavailableModule(for symbol: String) {
        stateLock.lock()
        defer { stateLock.unlock() }
        unavailableSymbols.insert(symbol)
    }

    func clearUnavailableModule(for symbol: String) {
        stateLock.lock()
        defer { stateLock.unlock() }
        unavailableSymbols.remove(symbol)
    }

    private func modulesSnapshot() -> [AnyModule] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return modules
    }

    private func unavailableSymbolsSnapshot() -> Set<String> {
        stateLock.lock()
        defer { stateLock.unlock() }
        return unavailableSymbols
    }

    /// The version of the collection engine behind a registered module.
    ///
    /// - Parameter key: The key of the module to look up, e.g. `ModuleKeys.deviceIntelligence`.
    /// - Returns: The engine version the module reports, or `nil` if no module
    ///   is registered for `key` or the registered module reports no version.
    ///
    /// Modules register themselves during `ModulesLoader.start()`, so this
    /// returns `nil` for every key until loading has run.
    public func version<Value>(for key: ModuleKey<Value>) -> String? {
        let modules = modulesSnapshot()
        let target = key as AnyObject
        return modules.first { ($0.key as AnyObject) === target }?.version()
    }

    /// Performs asynchronous initialization for all registered modules.
    ///
    /// Initialization is executed sequentially and errors
    /// are ignored to allow other modules to proceed.
    public func initialize() async {
        await lifecycleGate.acquire()
        let modules = modulesSnapshot()
        for module in modules {
            await module.initialize()
        }
        await lifecycleGate.release()
    }

    /// Starts asynchronous collection for all registered modules.
    ///
    /// A fresh call supersedes any in-flight run: modules left `.collecting`
    /// by a prior, superseded run are rolled back so they can restart. A
    /// module that already reached `.collected` is also restarted for a
    /// fresh collection — call this again in the same session
    /// (with or without reconfiguring first) to get a new payload; call
    /// `endCollect()` alone, with no new `startCollect()`, to replay the
    /// last one or to auto-start modules still in `.configured`
    /// (Android-aligned). Returns once work is scheduled; await results on
    /// `endCollect()`. Each module is invoked sequentially. Errors thrown
    /// synchronously by individual modules are caught and ignored.
    public func startCollect() async {
        await lifecycleGate.acquire()
        let modules = modulesSnapshot()
        for module in modules {
            module.cancelIfCollecting()
        }

        for module in modules {
            do {
                try await module.startCollect()
            } catch {
                handleError(module: module)
            }
        }
        await lifecycleGate.release()
    }

    /// Starts synchronous collection for all registered modules.
    ///
    /// Errors thrown by individual modules are caught and
    /// do not interrupt execution.
    /// Do not call this while an asynchronous lifecycle operation is active.
    public func startCollectSync() {
        let modules = modulesSnapshot()
        for module in modules {
            do {
                try module.startCollectSync()
            } catch {
                handleError(module: module)
            }
        }
    }

    /// Preloads or prepares collectors asynchronously.
    ///
    /// This method is intended for modules that require
    /// asynchronous preparation before collection begins.
    public func loadCollector() async {
        await lifecycleGate.acquire()
        let modules = modulesSnapshot()
        for module in modules {
            await module.loadCollector()
        }
        await lifecycleGate.release()
    }

    /// Preloads or prepares collectors synchronously.
    ///
    /// Errors thrown by individual modules are caught
    /// and do not interrupt execution.
    /// Do not call this while an asynchronous lifecycle operation is active.
    public func loadCollectorSync() {
        let modules = modulesSnapshot()
        for module in modules {
            do {
                try module.loadCollectorSync()
            } catch {
                handleError(module: module)
            }
        }
    }

    /// Ends collection for all registered modules and aggregates results.
    ///
    /// Each module contributes its result into the provided
    /// `ModuleCollection`. Per-module failures are recorded in the
    /// `ModuleCollection` rather than stopping aggregation.
    ///
    /// Modules in a startable state (`.configured`, or `.notConfigured` when
    /// no configure step is required) are auto-started before harvest,
    /// matching Android `endCollect()` behaviour.
    ///
    /// - Returns: A populated `ModuleCollection` holding each module's
    ///   output on success and its `ModuleError` on failure. Modules that
    ///   produced nothing contribute no entry.
    public func endCollect() async -> ModuleCollection {
        await lifecycleGate.acquire()

        var collection = ModuleCollection()
        let modules = modulesSnapshot()
        let unavailableSymbols = unavailableSymbolsSnapshot()

        // Schedule every End-only auto-start before awaiting any one module.
        // This preserves independent module concurrency without concurrently
        // mutating the shared collection.
        for module in modules {
            module.prepareToCollect()
        }

        for module in modules {
            await module.collect(into: &collection)
        }

        if unavailableSymbols.contains(CollectorSymbols.deviceIntelligence) {
            collection.insertError(
                ModuleKeys.deviceIntelligence,
                error: ModuleError.moduleUnavailable(
                    moduleKey: ModuleKeys.deviceIntelligence.name,
                    symbol: CollectorSymbols.deviceIntelligence
                )
            )
        }

        if unavailableSymbols.contains(CollectorSymbols.deviceInsight) {
            collection.insertError(
                ModuleKeys.deviceInsight,
                error: ModuleError.moduleUnavailable(
                    moduleKey: ModuleKeys.deviceInsight.name,
                    symbol: CollectorSymbols.deviceInsight
                )
            )
        }

        await lifecycleGate.release()
        return collection
    }

    /// Applies runtime configuration to all registered modules.
    ///
    /// A shared `ConfigureBuilder` is created and passed to the
    /// provided closure for setup before being applied to modules.
    ///
    /// Per-module configuration failures are logged and do not
    /// interrupt configuration of remaining modules.
    ///
    /// - Parameter build: A closure used to configure the builder.
    public func configure(
        _ build: (ConfigureBuilder) -> Void
    ) async {

        let builder = ConfigureBuilder()
        build(builder)

        await lifecycleGate.acquire()
        let modules = modulesSnapshot()
        for module in modules {
            await module.configure(builder)
        }
        await lifecycleGate.release()
    }

    /// Handles internal module errors.
    ///
    /// This method is intentionally minimal and may be
    /// expanded to support logging or telemetry.
    private func handleError(function: String = #function, module: AnyModule) {
        Logger.log(" -> Error -> method: \(function), module: \(module)", type: .error)
    }
}

// MARK: - Testing Support
#if DEBUG
extension ModularOrchestrator {

    /// Number of modules currently registered (test-only).
    public var testingRegisteredModuleCount: Int {
        modulesSnapshot().count
    }

    /// Clears all registered modules.
    ///
    /// Intended for use in unit tests to ensure
    /// a clean orchestrator state.
    public func reset() {
        stateLock.lock()
        defer { stateLock.unlock() }
        modules.removeAll()
        unavailableSymbols.removeAll()
    }
}
#endif
