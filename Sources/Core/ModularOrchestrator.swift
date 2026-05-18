//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModularOrchestrator.swift
//  ModularSDK
//
//

/// Configuration object used to initialize or customize UDI collection.
///
/// `UDIConfig` encapsulates configuration values required by UDI-related
/// modules, such as remote endpoints or environment-specific settings.
public struct UDIConfig {
    
    /// The URL used to configure the UDI collector.
    ///
    /// This value typically represents a remote endpoint or configuration
    /// resource required during the collection process.
    public var url: String
    
    /// Creates a new UDI configuration instance.
    ///
    /// - Parameter url: The configuration URL to be used by the UDI collector.
    public init(url: String) {
        self.url = url
    }
}

public typealias DIResponse = (String?, Int?)
public typealias UDIResponse = (payload: String?, transactionId: String?)

/// Well-known keys used to retrieve typed module results
/// from a `ModuleCollection`.
public enum ModuleKeys {
    public static let di = ModuleKey<DIResponse>("di")
    public static let udi = ModuleKey<UDIResponse>("udi")
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
/// - Not inherently thread-safe.
/// - Callers are responsible for ensuring serialized access.
///
/// - Important: Module execution order follows the
///   registration order and is not otherwise enforced.
public final class ModularOrchestrator {
    
    /// Shared singleton instance.
    public static let shared = ModularOrchestrator()
    
    /// Private initializer enforcing singleton usage.
    private init() {
        // Intentionally left empty.
    }
    
    /// Internal list of registered modules.
    ///
    /// Modules are executed in registration order.
    private var modules: [AnyModule] = []
    
    /// Registers a new module for orchestration.
    ///
    /// - Parameter module: A concrete type conforming to `Module`.
    ///
    /// Once registered, the module participates in all lifecycle
    /// operations propagated by the orchestrator.
    public func register<M: Module>(_ module: M) {
        modules.append(ModuleBox(module))
    }
    
    /// Performs asynchronous initialization for all registered modules.
    ///
    /// Initialization is executed sequentially and errors
    /// are ignored to allow other modules to proceed.
    public func initialize() async {
        for module in modules {
            await module.initialize()
        }
    }
    
    /// Starts asynchronous collection for all registered modules.
    ///
    /// Each module is invoked sequentially. Errors thrown by
    /// individual modules are caught and ignored.
    public func startCollect() async {
        for module in modules {
            do {
                try await module.startCollect()
            } catch {
                handleError(module: module)
            }
        }
    }
    
    /// Starts synchronous collection for all registered modules.
    ///
    /// Errors thrown by individual modules are caught and
    /// do not interrupt execution.
    public func startCollectSync() {
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
        for module in modules {
            handleError(module: module)
            await module.loadCollector()
        }
    }
    
    /// Preloads or prepares collectors synchronously.
    ///
    /// Errors thrown by individual modules are caught
    /// and do not interrupt execution.
    public func loadCollectorSync() {
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
    /// `ModuleCollection`. Errors thrown by individual modules
    /// are caught and do not stop aggregation.
    ///
    /// - Returns: A populated `ModuleCollection` containing
    ///   all successfully collected module outputs.
    public func endCollect() async -> ModuleCollection {
        
        var collection = ModuleCollection()
        
        for module in modules {
            do {
                try await module.collect(into: &collection)
            } catch {
                handleError(module: module)
            }
        }
        
        return collection
    }
    
    /// Applies runtime configuration to all registered modules.
    ///
    /// A shared `ConfigureBuilder` is created and passed to the
    /// provided closure for setup before being applied to modules.
    ///
    /// Errors thrown by individual modules are caught and
    /// do not interrupt configuration of remaining modules.
    ///
    /// - Parameter build: A closure used to configure the builder.
    public func configure(
        _ build: (ConfigureBuilder) -> Void
    ) async {
        
        let builder = DefaultConfigureBuilder()
        build(builder)
        
        for module in modules {
            do {
                try await module.configure(builder)
            } catch {
                handleError(module: module)
            }
        }
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
    
    /// Clears all registered modules.
    ///
    /// Intended for use in unit tests to ensure
    /// a clean orchestrator state.
    public func reset() {
        modules.removeAll()
    }
}
#endif
