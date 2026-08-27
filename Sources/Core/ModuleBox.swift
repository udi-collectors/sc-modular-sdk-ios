//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleBox.swift
//  ModularSDK
//
//

import Foundation

/// Upper bound applied to a module's configured `startCollect()` timeout, far
/// past any real collection. Keeps the conversion to the `UInt64` nanosecond
/// count required by `Task.sleep(nanoseconds:)` in representable range.
private let maxCollectTimeout: TimeInterval = 86_400

/// Resolves the first result in the collect/timeout race without requiring the
/// losing task to finish. This is intentionally unstructured: vendor collector
/// work does not honor Swift task cancellation, while the public timeout must
/// still bound how long callers wait.
private final class CollectRace {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var tasks: [Task<Void, Never>] = []
    private var result: Result<Void, Error>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func install(tasks: [Task<Void, Never>]) {
        lock.lock()
        self.tasks = tasks
        let completed = result != nil
        lock.unlock()

        if completed {
            tasks.forEach { $0.cancel() }
        }
    }

    func resolve(_ result: Result<Void, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        let tasks = self.tasks
        lock.unlock()

        tasks.forEach { $0.cancel() }
        continuation?.resume(with: result)
    }
}

/// Bridges cancellation of the parent collection task into an unstructured race.
private final class CollectRaceCancellation {
    private let lock = NSLock()
    private var race: CollectRace?
    private var isCancelled = false

    func install(_ race: CollectRace) {
        lock.lock()
        self.race = race
        let shouldCancel = isCancelled
        lock.unlock()

        if shouldCancel {
            race.resolve(.failure(CancellationError()))
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let race = race
        lock.unlock()
        race?.resolve(.failure(CancellationError()))
    }
}

/// Publishes completion of synchronous vendor work to async harvest callers.
final class SyncCollectCompletion {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var result: Result<Void, Error>?

    func wait() async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result {
                lock.unlock()
                continuation.resume(with: result)
                return
            }
            self.continuation = continuation
            lock.unlock()
        }
    }

    func resolve(_ result: Result<Void, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

/// Type-erased wrapper around a concrete `Module` instance.
///
/// `ModuleBox` adapts a generic `Module` into the `AnyModule`
/// interface, allowing heterogeneous modules to be stored and
/// orchestrated uniformly by `ModularOrchestrator`.
final class ModuleBox<M: Module>: AnyModule {

    /// The wrapped concrete module instance.
    private let module: M
    private let stateLock = NSRecursiveLock()
    private var lifecycleState: ModuleLifecycleState = .notConfigured

    /// The current lifecycle state of the wrapped module.
    public private(set) var state: ModuleLifecycleState {
        get { withStateLock { lifecycleState } }
        set { withStateLock { lifecycleState = newValue } }
    }

    /// `AnyModule` conformance for `state`. Named `currentState()`, not
    /// `state()` — see the note on the protocol requirement — so it coexists
    /// with the stored property above rather than colliding with it.
    public func currentState() -> ModuleLifecycleState {
        state
    }

    /// The timeout applied to `startCollect()`, captured from the last
    /// `configure(_:)` call. Defaults to the standard 15s builder default
    /// for boxes that are never configured (e.g. `Void`/`NoConfig` modules).
    private var timeout: TimeInterval = ConfigureBuilder().timeout

    /// Clamps a configured timeout for the SDK-imposed `startCollect()` bound.
    /// Non-positive and non-finite values use the standard finite default.
    /// Values above `maxCollectTimeout` use that upper bound; any other positive
    /// value is the race limit in seconds.
    static func sanitizedTimeout(_ timeout: TimeInterval) -> TimeInterval {
        guard timeout.isFinite, timeout > 0 else { return defaultCollectTimeout }
        return min(timeout, maxCollectTimeout)
    }

#if DEBUG
    /// When set, the next `launchCollectWork()` call throws this error (test-only).
    var testingThrowOnNextLaunchCollect: Error?
#endif

    /// The in-flight collection work for the current `startCollect()` run, if any.
    /// Retained so a superseding run can cancel it via `cancelIfCollecting()`.
    private var currentCollectTask: Task<Void, Error>?
    private var currentCollectIsSynchronous = false
    private var pendingLaunchError: Error?

    // Detecting whether a completing run has been superseded would naturally be an
    // identity comparison such as `self.currentCollectTask === task`, but `Task` is a
    // struct (no `AnyObject` conformance), so `===` does not compile. A monotonically
    // increasing generation counter provides the same "am I still the owning run?"
    // check without changing `currentCollectTask`'s type or the cancellation call site.
    private var currentCollectGeneration = 0

    /// The module's last successful `collect(into:)` outcome.
    /// Populated on `.success`/`nil` from `module.endCollect()`, never on
    /// `.failure` — a failed pass already has correct rollback-and-retry
    /// semantics and has nothing valid to cache. Replayed on a
    /// later `collect(into:)` call made while `.collected` and not currently
    /// `.collecting`, instead of reporting `.notCollecting`.
    private enum CachedOutcome {
        case value(M.Output)
        case nothing
    }
    private var cachedOutcome: CachedOutcome?

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

    /// The version of the collection engine the wrapped module reports.
    public func version() -> String? {
        module.version()
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
        // `.configured` and `.collected` are allowed through in addition to
        // `.notConfigured`: an already-configured module can be reconfigured
        // with fresh values, and a module that already completed a successful
        // cycle can be reconfigured before a fresh `startCollect()` restart.
        // A no-op or failed reconfigure attempt leaves `state` untouched, so
        // the cached result from the prior cycle is still replayed by
        // `collect(into:)` until a reconfigure actually lands. Only a module
        // genuinely mid-collection (`.collecting`) is rejected.
        guard state == .notConfigured || state == .configured || state == .collected else {
            let reason = ModuleError.invalidLifecycleState(moduleKey: module.key.name, state: state)
            Logger.log("Skipping configure: \(reason)", type: .error)
            return
        }

        // `builder.timeout` is deliberately captured here — below the lifecycle-state
        // guard, above the missing-config/cast guards. Capturing it any earlier would
        // let a rejected `configure()` still change the timeout used by the next
        // collection cycle. Capturing it any later would miss the case it exists for:
        // `NoConfig`/`Void` modules never receive a config value, so they must still
        // pick up a custom timeout via those early returns.
        withStateLock {
            timeout = builder.timeout
        }

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

        switch await module.configure(config) {
        case .success:
            state = .configured
        case .failure(let error):
            Logger.log("Configure failed for module \(module.key.name): \(error)", type: .error)
        }
    }

    /// Throws `.notConfigured` if the wrapped module requires configuration
    /// but has not been configured yet. `Void` and `NoConfig` mean not required.
    private func ensureConfiguredIfRequired() throws {
        let requiresConfig = Self.configRequired(for: M.Config.self)
        if requiresConfig && state == .notConfigured {
            throw ModuleError.notConfigured(moduleKey: module.key.name)
        }
    }

    /// Throws `.invalidLifecycleState` if the module is already `.collecting`
    /// or `.collected`. Used by the synchronous `startCollectSync()`, which
    /// intentionally does not support restarting a `.collected` module — a
    /// failed `endCollect()` still rolls the state back to make it startable
    /// again (see `collect(into:)`). Only the async `startCollect()` allows
    /// restarting from `.collected` (see `ensureNotCollecting()`).
    private func ensureNotAlreadyStarted() throws {
        guard state == .collecting || state == .collected else { return }
        throw ModuleError.invalidLifecycleState(moduleKey: module.key.name, state: state)
    }

    /// Throws `.invalidLifecycleState` only if the module is currently
    /// `.collecting`. Used by the async `startCollect()`, which — unlike
    /// `startCollectSync()` — allows restarting a `.collected` module for a
    /// fresh collection in the same session. A module still
    /// genuinely mid-collection from a superseded run is already rolled back
    /// via `cancelIfCollecting()` before this would ever see `.collecting`
    /// again for the same logical run.
    private func ensureNotCollecting() throws {
        guard state == .collecting else { return }
        throw ModuleError.invalidLifecycleState(moduleKey: module.key.name, state: state)
    }

    private static func configRequired(for configType: Any.Type) -> Bool {
        configType != Void.self && configType != NoConfig.self
    }

    /// Error surfaced when `collect(into:)` runs while the module is not collecting.
    private func collectionBlockedError() -> ModuleError {
        if state == .notConfigured && Self.configRequired(for: M.Config.self) {
            return .notConfigured(moduleKey: module.key.name)
        }
        return .notCollecting(moduleKey: module.key.name)
    }

    /// Whether `collect(into:)` should invoke `launchCollectWork()` before
    /// harvesting — mirrors Android `endCollect()` auto-starting modules in
    /// `CONFIGURED` (and DeviceInsight-style modules that need no configure step).
    private func shouldAutoStartBeforeCollect() -> Bool {
        switch state {
        case .configured:
            return true
        case .notConfigured:
            return !Self.configRequired(for: M.Config.self)
        default:
            return false
        }
    }

    private func runModuleStartCollect() async throws {
        try await module.startCollect()
    }

    private func startCollectTask(resolving race: CollectRace) -> Task<Void, Never> {
        Task {
            do {
                try await runModuleStartCollect()
                race.resolve(.success(()))
            } catch {
                race.resolve(.failure(error))
            }
        }
    }

    private func makeTimeoutTask(
        after timeout: TimeInterval,
        moduleKeyName: String,
        resolving race: CollectRace
    ) -> Task<Void, Never> {
        Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                race.resolve(.failure(ModuleError.timeout(moduleKey: moduleKeyName)))
            } catch {
                // The collect task won and cancelled this timer.
            }
        }
    }

    /// Races the wrapped module's `startCollect()` against the configured
    /// timeout, whichever finishes first.
    ///
    /// The first result wins. The caller resumes immediately and the losing
    /// task is cancelled without waiting for cancellation-resistant vendor
    /// work to stop.
    ///
    /// - Parameters:
    ///   - timeout: Positive race limit in seconds.
    ///   - moduleKeyName: Captured by the caller so the timeout error names the
    ///     module without touching `self` from inside the child task.
    private func raceStartCollectAgainstTimeout(
        _ timeout: TimeInterval,
        moduleKeyName: String
    ) async throws {
        let cancellation = CollectRaceCancellation()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let race = CollectRace(continuation: continuation)
                cancellation.install(race)
                let collectTask = startCollectTask(resolving: race)
                let timeoutTask = makeTimeoutTask(
                    after: timeout,
                    moduleKeyName: moduleKeyName,
                    resolving: race
                )
                race.install(tasks: [collectTask, timeoutTask])
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    /// Runs the wrapped module's `startCollect()`, bounded by the sanitized
    /// timeout.
    private func performCollectWork(timeout: TimeInterval, moduleKeyName: String) async throws {
        try await raceStartCollectAgainstTimeout(timeout, moduleKeyName: moduleKeyName)
    }

    private func scheduleFallbackRollback(for task: Task<Void, Error>, generation: Int) {
        Task {
            do {
                try await task.value
            } catch {
                self.rollbackAfterFailedLaunch(generation: generation)
            }
        }
    }

    /// Starts async collection work without awaiting completion.
    private func launchCollectWork() throws {
#if DEBUG
        if let injected = testingThrowOnNextLaunchCollect {
            testingThrowOnNextLaunchCollect = nil
            throw injected
        }
#endif
        let (task, generation) = try withStateLock { () -> (Task<Void, Error>, Int) in
            try ensureNotCollecting()
            try ensureConfiguredIfRequired()
            state = .collecting
            currentCollectGeneration += 1
            let generation = currentCollectGeneration
            let timeout = Self.sanitizedTimeout(self.timeout)
            let moduleKeyName = module.key.name
            let task = Task<Void, Error> {
                try await self.performCollectWork(timeout: timeout, moduleKeyName: moduleKeyName)
            }
            currentCollectTask = task
            currentCollectIsSynchronous = false
            return (task, generation)
        }
        scheduleFallbackRollback(for: task, generation: generation)
    }

    private func rollbackAfterFailedLaunch(generation: Int) {
        withStateLock {
            guard currentCollectGeneration == generation else { return }
            currentCollectTask = nil
            currentCollectIsSynchronous = false
            state = Self.configRequired(for: M.Config.self) ? .configured : .notConfigured
        }
    }

    public func startCollect() async throws {
        try launchCollectWork()
    }

    public func cancelIfCollecting() {
        let task = withStateLock { () -> Task<Void, Error>? in
            guard state == .collecting, !currentCollectIsSynchronous else { return nil }
            let task = currentCollectTask
            currentCollectTask = nil
            currentCollectIsSynchronous = false
            state = Self.configRequired(for: M.Config.self) ? .configured : .notConfigured
            return task
        }
        task?.cancel()
    }

    func prepareToCollect() {
        guard shouldAutoStartBeforeCollect() else { return }
        do {
            try launchCollectWork()
        } catch {
            withStateLock { pendingLaunchError = error }
        }
    }

    public func collect(into collection: inout ModuleCollection) async {
        if let launchError = withStateLock({ () -> Error? in
            defer { pendingLaunchError = nil }
            return pendingLaunchError
        }) {
            collection.insertError(
                module.key,
                error: (launchError as? ModuleError) ?? .underlying(launchError)
            )
            return
        }

        if shouldAutoStartBeforeCollect() {
            do {
                try launchCollectWork()
            } catch {
                collection.insertError(
                    module.key,
                    error: (error as? ModuleError) ?? .underlying(error)
                )
                return
            }
        }

        let taskSnapshot = withStateLock { (currentCollectTask, currentCollectGeneration) }
        if let inFlight = taskSnapshot.0 {
            let generation = taskSnapshot.1
            do {
                try await inFlight.value
            } catch {
                rollbackAfterFailedLaunch(generation: generation)
                collection.insertError(module.key, error: (error as? ModuleError) ?? .underlying(error))
                return
            }
        }

        let stateSnapshot = withStateLock { (lifecycleState, cachedOutcome) }
        guard stateSnapshot.0 == .collecting else {
            if stateSnapshot.0 == .collected, let cachedOutcome = stateSnapshot.1 {
                switch cachedOutcome {
                case .value(let value):
                    collection.insert(module.key, value: value)
                case .nothing:
                    break
                }
                return
            }
            collection.insertError(module.key, error: collectionBlockedError())
            return
        }

        switch module.endCollect() {
        case .success(let value):
            withStateLock {
                lifecycleState = .collected
                cachedOutcome = .value(value)
                currentCollectTask = nil
                currentCollectIsSynchronous = false
            }
            collection.insert(module.key, value: value)
        case .failure(let error):
            collection.insertError(module.key, error: error)
            withStateLock {
                lifecycleState = Self.configRequired(for: M.Config.self) ? .configured : .notConfigured
                currentCollectTask = nil
                currentCollectIsSynchronous = false
            }
        case .none:
            withStateLock {
                lifecycleState = .collected
                cachedOutcome = .nothing
                currentCollectTask = nil
                currentCollectIsSynchronous = false
            }
        }
    }

    public func initialize() async {
        await module.initialize()
    }

    public func startCollectSync() throws {
        let completion = SyncCollectCompletion()
        let task = Task<Void, Error> {
            try await completion.wait()
        }
        let generation: Int
        do {
            generation = try withStateLock {
                try ensureNotAlreadyStarted()
                try ensureConfiguredIfRequired()
                state = .collecting
                currentCollectGeneration += 1
                currentCollectTask = task
                currentCollectIsSynchronous = true
                return currentCollectGeneration
            }
        } catch {
            completion.resolve(.failure(error))
            throw error
        }
        do {
            try module.startCollectSync()
            completion.resolve(.success(()))
        } catch {
            completion.resolve(.failure(error))
            rollbackAfterFailedLaunch(generation: generation)
            throw error
        }
    }

    public func loadCollector() async {
        await module.loadCollector()
    }

    public func loadCollectorSync() throws {
        try module.loadCollectorSync()
    }

#if DEBUG
    func testingForceState(_ state: ModuleLifecycleState) {
        self.state = state
    }

    func testingClearCachedOutcome() {
        withStateLock { cachedOutcome = nil }
    }
#endif

    private func withStateLock<Value>(_ body: () throws -> Value) rethrows -> Value {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try body()
    }
}
