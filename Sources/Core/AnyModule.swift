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
protocol AnyModule {

    /// The unique, type-erased key identifying the module output.
    ///
    /// This key is used during result aggregation to insert values into
    /// `ModuleCollection`.
    var key: Any { get }

    /// The current lifecycle state of the module.
    ///
    /// A method rather than a `{ get }` property, for the same reason as
    /// `Module.version()` — see the note there. Named `currentState()` rather
    /// than `state()`: every conformer already has a stored `state` property
    /// for its own internal bookkeeping, and Swift does not allow a stored
    /// property and a zero-argument method to share one base name in the same
    /// type. Nothing calls this through an `AnyModule` existential today —
    /// each conformer's own `state` property is used directly instead — so the
    /// rename has no call sites to update.
    func currentState() -> ModuleLifecycleState

    /// The version of the collection engine the wrapped module reports,
    /// or `nil` when it reports none.
    ///
    /// A method rather than a `{ get }` property, mirroring `Module.version()`
    /// — see the note there.
    func version() -> String?

    /// Applies runtime configuration to the module.
    ///
    /// - Parameter builder: A configuration builder populated by the orchestrator.
    /// - Note: Configuration failures are logged, not thrown.
    func configure(_ builder: ConfigureBuilder) async

    /// Schedules asynchronous data collection and returns once it is under way.
    ///
    /// - Throws: Only the synchronous entry guards — `.invalidLifecycleState` or
    ///   `.notConfigured`. Errors and timeouts produced by the underlying module
    ///   surface later, on `collect(into:)`.
    func startCollect() async throws

    /// Rolls back the module if it is currently `.collecting`, so a
    /// superseding `startCollect()` run can restart it. No-op otherwise.
    func cancelIfCollecting()

    /// Schedules collection when the module is in an auto-startable state.
    func prepareToCollect()

    /// Ends collection and inserts the module result into the given collection.
    ///
    /// This method is responsible for retrieving the module output and
    /// inserting it into the shared `ModuleCollection`.
    ///
    /// - Parameter collection: The collection used to aggregate module results.
    /// - Note: Non-throwing. A module failure is recorded in `collection`
    ///   as a `ModuleError` rather than propagated to the caller.
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
