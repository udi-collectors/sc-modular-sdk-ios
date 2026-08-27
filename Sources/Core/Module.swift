//  Copyright (c) Experian, 2026. All rights reserved.

/// Contract that every dynamic module must conform to in order to integrate
/// with `ModularOrchestrator`.
public protocol Module {
    /// Value produced by this module after collection.
    associatedtype Output

    /// Runtime configuration accepted by this module. Use `NoConfig` when
    /// configuration is not required.
    associatedtype Config

    /// Canonical identity key used for configuration and result lookup.
    var key: ModuleKey<Output> { get }

    /// Reports the wrapped collector engine version, when available.
    /// This remains a method to avoid exposing a duplicate getter surface to
    /// static analysis while still allowing a default implementation.
    func version() -> String?

    /// Performs optional collector initialization.
    func initialize() async

    /// Starts asynchronous collection. Completion and errors are consumed by
    /// the orchestrator at `endCollect()`.
    func startCollect() async throws

    /// Starts collection synchronously on the calling thread.
    func startCollectSync() throws

    /// Preloads collector resources asynchronously without starting collection.
    func loadCollector() async

    /// Preloads collector resources synchronously on the calling thread.
    func loadCollectorSync() throws

    /// Returns the latest collected value or module failure, or `nil` when the
    /// module has no result to contribute.
    func endCollect() -> ModuleResult<Output>?

    /// Applies typed runtime configuration.
    func configure(_ configure: Config) async -> ModuleResult<Void>
}

public extension Module {
    func version() -> String? { nil }
    func loadCollector() async {
        // Optional hook: most modules collect without a separate preload step.
    }
    func loadCollectorSync() throws {
        // Optional hook: most modules collect without a separate preload step.
    }
    func initialize() async {
        // Optional hook: modules with no initialization work use this default.
    }
}
