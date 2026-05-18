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
    /// - Throws: Rethrows any error thrown by the underlying module.
    public func configure(_ builder: ConfigureBuilder) async throws {
        guard let config: M.Config = builder.getConfig(for: module.key) else { return }
        
        try await module.configure(config)
    }
    
    /// Starts asynchronous data collection on the wrapped module.
    ///
    /// - Throws: Rethrows any error thrown by the underlying module.
    public func startCollect() async throws {
        try await module.startCollect()
    }
    
    /// Ends collection and inserts the module result into the given collection.
    ///
    /// If the module returns `nil` from `endCollect()`, no value
    /// is inserted and the operation is silently ignored.
    ///
    /// - Parameters:
    ///   - collection: The shared `ModuleCollection` used to
    ///     aggregate results across modules.
    /// - Throws: Rethrows any error thrown by `endCollect()`.
    public func collect(into collection: inout ModuleCollection) async {
        do {
            if let value = try await module.endCollect() {
                collection.insert(module.key, value: value)
            }
        } catch let error {
            collection.insertError(module.key, error: error)
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
