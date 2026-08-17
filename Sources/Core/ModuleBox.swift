//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleBox.swift
//  ModularSDK
//
//

/// Type-erased wrapper around a concrete `Module` instance.
///
/// `ModuleBox` adapts a generic `Module` into the `AnyModule`
/// interface, allowing heterogeneous modules to be stored and
/// orchestrated uniformly by `ModularOrchestrator`.
public final class ModuleBox<M: Module>: AnyModule {
    
    /// The wrapped concrete module instance.
    private let module: M
    
    /// Creates a type-erased wrapper for the given module.
    ///
    /// - Parameter module: A concrete type conforming to `Module`.
    public init(_ module: M) {
        self.module = module
    }
    
    /// The unique key associated with the wrapped module.
    ///
    /// This key is used to insert collected values into
    /// `ModuleCollection` during aggregation.
    public var key: Any {
        module.key
    }
    
    /// Applies runtime configuration to the wrapped module.
    ///
    /// - Parameter builder: A configuration builder populated
    ///   by the orchestrator.
    ///
    /// Behavior:
    /// - If no config was set for the module's key, the configure is
    ///   skipped and logged at `.default` (a missing config can be legitimate).
    ///   `.default` is the closest warning-equivalent level: `OSLogType` has no
    ///   `.warning` case, and `.error` would overstate a legitimate condition.
    /// - If a config was set but fails to cast to `M.Config`, the configure
    ///   is skipped and logged at `.error`.
    /// - If the module's `configure` returns `.failure`, the failure is
    ///   logged at `.error`.
    public func configure(_ builder: ConfigureBuilder) async {
        guard builder.hasConfig(for: module.key) else {
            let reason = ModuleError.missingConfig(moduleKey: module.key.name)
            Logger.log("Skipping configure: \(reason)", type: .default)
            return
        }

        guard let config: M.Config = builder.getConfig(for: module.key) else {
            let reason = ModuleError.invalidConfig(moduleKey: module.key.name)
            Logger.log("Skipping configure: \(reason)", type: .error)
            return
        }

        if case .failure(let error) = await module.configure(config) {
            Logger.log("Configure failed for module \(module.key.name): \(error)", type: .error)
        }
    }
    
    /// Starts asynchronous data collection on the wrapped module.
    ///
    /// - Throws: Rethrows any error thrown by the underlying module.
    public func startCollect() async throws {
        try await module.startCollect()
    }
    
    /// Ends collection and inserts the module result into the given collection.
    ///
    /// - Parameters:
    ///   - collection: The shared `ModuleCollection` used to
    ///     aggregate results across modules.
    ///
    /// Behavior:
    /// - `.success(let value)` inserts the value into the collection.
    /// - `.failure(let error)` inserts the error into the collection.
    /// - `nil` inserts nothing.
    public func collect(into collection: inout ModuleCollection) async {
        switch module.endCollect() {
        case .success(let value):
            collection.insert(module.key, value: value)
        case .failure(let error):
            collection.insertError(module.key, error: error)
        case .none:
            break
        }
    }
    
    /// Performs asynchronous initialization on the wrapped module.
    public func initialize() async {
        await module.initialize()
    }
    
    /// Starts synchronous data collection on the wrapped module.
    ///
    /// - Throws: Rethrows any error thrown by the underlying module.
    public func startCollectSync() throws {
        try module.startCollectSync()
    }
    
    /// Loads or preloads collector resources asynchronously.
    public func loadCollector() async {
        await module.loadCollector()
    }
    
    /// Loads or preloads collector resources synchronously.
    ///
    /// - Throws: Rethrows any error thrown by the underlying module.
    public func loadCollectorSync() throws {
        try module.loadCollectorSync()
    }
    
}
