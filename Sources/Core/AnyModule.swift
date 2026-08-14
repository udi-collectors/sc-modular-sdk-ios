//  Copyright (c) Experian, 2026. All rights reserved.
//
//  AnyModule.swift
//  ModularSDK
//
//

/// Type-erased interface used internally by the orchestrator.
///
/// `AnyModule` provides a unified, non-generic abstraction over concrete
/// `Module` implementations, allowing heterogeneous modules with different
/// output types to be stored, managed, and orchestrated together.
///
/// This protocol is not intended to be implemented directly by SDK consumers.
/// Instead, concrete `Module` instances are adapted to `AnyModule` via
/// type-erasing wrappers such as `ModuleBox`.
public protocol AnyModule {
    
    /// The unique, type-erased key identifying the module output.
    ///
    /// This key is used during result aggregation to insert values into
    /// `ModuleCollection`.
    var key: Any { get }
    
    /// Applies runtime configuration to the module.
    ///
    /// - Parameter builder: A configuration builder populated by the orchestrator.
    /// - Note: Configuration failures are logged, not thrown.
    func configure(_ builder: ConfigureBuilder) async
    
    /// Starts asynchronous data collection.
    ///
    /// - Throws: Rethrows any error produced by the underlying module.
    func startCollect() async throws
    
    /// Ends collection and inserts the module result into the given collection.
    ///
    /// This method is responsible for retrieving the module output and
    /// inserting it into the shared `ModuleCollection`.
    ///
    /// - Parameter collection: The collection used to aggregate module results.
    /// - Throws: Rethrows any error produced during result finalization.
    func collect(into collection: inout ModuleCollection) async
    
    /// Performs asynchronous initialization or setup.
    ///
    /// This method is typically invoked before collection begins.
    func initialize() async
    
    /// Starts synchronous data collection.
    ///
    /// - Throws: Rethrows any error produced by the underlying module.
    func startCollectSync() throws
    
    /// Loads or preloads collector resources asynchronously.
    ///
    /// Intended for preparing resources required for collection.
    func loadCollector() async
    
    /// Loads or preloads collector resources synchronously.
    ///
    /// - Throws: Rethrows any error produced during resource loading.
    func loadCollectorSync() throws
    
}
