//  Copyright (c) Experian, 2026. All rights reserved.
//
//  Loader.swift
//  ModularSDK
//
//
import Foundation

/// C-compatible function signature used to dynamically
/// load a module at runtime.
typealias ModuleLoaderFunc = @convention(c) () -> Void

/// Symbol resolver used to locate dynamic entry points.
///
/// - Parameters:
///   - handle: Dynamic library handle.
///   - symbol: C symbol name.
/// - Returns: Pointer to the resolved symbol.
typealias SymbolResolver = (_ handle: UnsafeMutableRawPointer?, _ symbol: String) -> UnsafeMutableRawPointer?

/// Outcome of dynamic collector discovery.
public struct ModuleLoadingResult: Equatable {
    /// All collector symbols loaded in the process after this start attempt.
    public let loadedSymbols: [String]

    /// Collector symbols that remain unresolved after this start attempt.
    public let missingSymbols: [String]

    public init(loadedSymbols: [String], missingSymbols: [String]) {
        self.loadedSymbols = loadedSymbols
        self.missingSymbols = missingSymbols
    }

    public var loadedAllModules: Bool { missingSymbols.isEmpty }
}

enum LoaderDefaults {
    static func resolveSymbol(
        _ handle: UnsafeMutableRawPointer?,
        _ symbol: String
    ) -> UnsafeMutableRawPointer? {
        dlsym(handle, symbol)
    }
}

/// Responsible for dynamically discovering and loading
/// available modules at runtime.
///
/// Architecture:
/// - Uses `dlsym` to resolve C entry points.
/// - Invokes discovered loader functions.
/// - Tracks successfully loaded modules.
///
/// Usage:
/// ```
/// ModulesLoader.start()
/// ```
///
/// Threading:
/// - `start()`, loaded-symbol state, and test resolver overrides are protected
///   by a recursive lock.
public class ModulesLoader {

    private static let lock = NSRecursiveLock()
    private static var loadedSymbols: [String] = []

    /// List of successfully loaded module symbols.
    public internal(set) static var modulesLoaded: [String] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return loadedSymbols
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            loadedSymbols = newValue
        }
    }

    /// When non-`nil`, used instead of `LoaderDefaults.resolveSymbol` (e.g. in unit tests).
    private static var resolverOverride: SymbolResolver?

    /// Symbol resolution strategy.
    ///
    /// Defaults to `dlsym`, but can be overridden for testing.
    static var resolver: SymbolResolver {
        get {
            lock.lock()
            defer { lock.unlock() }
            return resolverOverride ?? LoaderDefaults.resolveSymbol
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            resolverOverride = newValue
        }
    }

    /// Starts dynamic module discovery.
    ///
    /// This method attempts to resolve predefined
    /// C entry points and execute them.
    @discardableResult
    public static func start() -> ModuleLoadingResult {
        lock.lock()
        defer { lock.unlock() }
        return loadAvailableModules()
    }

    /// Attempts to resolve and execute known module symbols.
    ///
    /// Currently supported symbols:
    /// - `load_device_intelligence_collector`
    /// - `load_device_insight_collector`
    private static func loadAvailableModules() -> ModuleLoadingResult {
        var missingSymbols: [String] = []

        CollectorSymbols.all.forEach { symbol in
            guard !modulesLoaded.contains(symbol) else { return }

            // Logged after the load actually happens. Logging before the
            // resolve claimed "loaded <symbol>" even when `dlsym` returned nil
            // and nothing was loaded — which is exactly the case someone reads
            // this log to diagnose.
            guard let symbolPointer = resolver(UnsafeMutableRawPointer(bitPattern: -2), symbol) else {
                missingSymbols.append(symbol)
                ModularOrchestrator.shared.recordUnavailableModule(for: symbol)
                Logger.log("symbol not found, module not loaded: \(symbol)", type: .error)
                return
            }

            let loader = unsafeBitCast(symbolPointer, to: ModuleLoaderFunc.self)
            loader()
            modulesLoaded.append(symbol)
            ModularOrchestrator.shared.clearUnavailableModule(for: symbol)
            Logger.log("loaded \(symbol)", type: .default)
        }

        return ModuleLoadingResult(
            loadedSymbols: modulesLoaded,
            missingSymbols: missingSymbols
        )
    }
}

#if DEBUG
extension ModulesLoader {
    /// Clears a test-injected resolver override so the production default applies again.
    static func resetResolverForTesting() {
        lock.lock()
        defer { lock.unlock() }
        resolverOverride = nil
    }
}
#endif
