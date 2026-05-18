//  Copyright (c) Experian, 2026. All rights reserved.
//
//  Loader.swift
//  ModularSDK
//
//
import Foundation

/// C-compatible function signature used to dynamically
/// load a module at runtime.
public typealias ModuleLoaderFunc = @convention(c) () -> Void

/// Symbol resolver used to locate dynamic entry points.
///
/// - Parameters:
///   - handle: Dynamic library handle.
///   - symbol: C symbol name.
/// - Returns: Pointer to the resolved symbol.
public typealias SymbolResolver = (_ handle: UnsafeMutableRawPointer?, _ symbol: String) -> UnsafeMutableRawPointer?

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
/// - Intended to be executed during SDK bootstrap.
/// - Not thread-safe.
public class ModulesLoader {
    
    /// List of successfully loaded module symbols.
    public static var modulesLoaded: [String] = []

    /// Symbol resolution strategy.
    ///
    /// Defaults to `dlsym`, but can be overridden for testing.
    static public var resolver: SymbolResolver = { handle, symbol in
        dlsym(handle, symbol)
    }
    
    /// Starts dynamic module discovery.
    ///
    /// This method attempts to resolve predefined
    /// C entry points and execute them.
    public static func start() {
        loadAvailableModules()
    }
    
    /// Attempts to resolve and execute known module symbols.
    ///
    /// Currently supported symbols:
    /// - `load_collector`
    /// - `load_di_collector`
    private static func loadAvailableModules() {
        let moduleSymbols = [
            "load_collector",
            "load_di_collector"
        ]
        
        moduleSymbols.forEach { symbol in
            Logger.log("loaded \(symbol)", type: .default)
            if let symbolPointer = resolver(UnsafeMutableRawPointer(bitPattern: -2), symbol) {
                let loader = unsafeBitCast(symbolPointer, to: ModuleLoaderFunc.self)
                loader()
                modulesLoaded.append(symbol)
            }
        }
    }
}
