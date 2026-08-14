//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ConfigureBuilder.swift
//  ModularSDK
//
//

import Foundation

/// Defines a contract for providing runtime configuration to modules.
///
/// `ConfigureBuilder` acts as a shared configuration container populated
/// by the orchestrator and consumed by modules during the configuration phase.
/// Configuration values are typically keyed using `ModuleKey` to ensure
/// strong typing at retrieval time.
public protocol ConfigureBuilder {
    
    /// Global timeout value, expressed in seconds.
    ///
    /// Modules may choose to read or ignore this value depending
    /// on their specific configuration needs.
    var timeout: TimeInterval { get }
    
    /// Associates a configuration value with the given module key.
    ///
    /// The provided value is stored using the identity of the key and
    /// can later be retrieved by modules using the same `ModuleKey` instance.
    ///
    /// - Parameters:
    ///   - key: A typed module key identifying the configuration entry.
    ///   - config: The configuration value to associate with the key.
    func setConfig<Value>(
        for key: ModuleKey<Value>,
        config: Any?
    )
        
    /// Retrieves the configuration value associated with the given module key.
    ///
    /// The returned value must be cast by the caller to the expected type.
    ///
    /// - Parameter key: A typed module key identifying the configuration entry.
    /// - Returns: The stored configuration value, or `nil` if no value exists
    ///   for the given key.
    func getConfig<Value, Config>(
        for key: ModuleKey<Value>
    ) -> Config?
    
    /// Reports whether a configuration value has been set for the given module key.
    ///
    /// This is a presence check only — it performs no cast, so a stored value
    /// of the wrong type still reports `true`.
    ///
    /// - Parameter key: A typed module key identifying the configuration entry.
    /// - Returns: `true` if a value has been set for the key, `false` otherwise.
    func hasConfig<Value>(
        for key: ModuleKey<Value>
    ) -> Bool
}
