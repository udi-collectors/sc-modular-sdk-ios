//  Copyright (c) Experian, 2026. All rights reserved.
//
//  DefaultConfigureBuilder.swift
//  ModularSDK
//
//

import Foundation

/// Default implementation of `ConfigureBuilder` used by the orchestrator.
///
/// `DefaultConfigureBuilder` stores configuration values in an
/// internal dictionary keyed by `ModuleKey` identity, allowing modules
/// to retrieve strongly-typed configuration data at runtime.
public final class DefaultConfigureBuilder: ConfigureBuilder {

    /// Default timeout value used by modules, in seconds.
    ///
    /// Modules may choose to read or ignore this value depending
    /// on their configuration needs.
    public var timeout: TimeInterval = 15
    
    public init() { }
    
    /// Internal storage for configuration values.
    ///
    /// Values are stored using `ObjectIdentifier` derived from `ModuleKey`
    /// to ensure key uniqueness across generic specializations.
    private(set) var configs: [ObjectIdentifier: Any] = [:]
    
    /// Associates a configuration value with the given module key.
    ///
    /// This method allows storing arbitrary configuration data that can
    /// later be retrieved by modules using the same `ModuleKey` instance.
    /// Passing `nil` removes any existing entry for the key.
    ///
    /// - Parameters:
    ///   - key: A typed `ModuleKey` identifying the configuration entry.
    ///   - config: The configuration value to associate with the key, or
    ///     `nil` to remove any existing entry.
    public func setConfig<Value>(
        for key: ModuleKey<Value>,
        config: Any?
    ) {
        if let config = config {
            configs[ObjectIdentifier(key)] = config
        } else {
            configs.removeValue(forKey: ObjectIdentifier(key))
        }
    }
    
    /// Retrieves the configuration value associated with the given module key.
    ///
    /// The returned value must be cast by the caller to the expected type.
    ///
    /// - Parameter key: A typed `ModuleKey` identifying the configuration entry.
    /// - Returns: The stored configuration value, or `nil` if no value
    ///   has been associated with the key or the stored value fails the cast.
    public func getConfig<Value, Config>(for key: ModuleKey<Value>) -> Config? {
        guard let raw = configs[ObjectIdentifier(key)] else { return nil }
        return raw as? Config
    }
    
    /// Reports whether a configuration value has been set for the given module key.
    ///
    /// This is a presence check only — it performs no cast, so a stored value
    /// of the wrong type still reports `true`.
    ///
    /// - Parameter key: A typed `ModuleKey` identifying the configuration entry.
    /// - Returns: `true` if a value has been set for the key, `false` otherwise.
    public func hasConfig<Value>(for key: ModuleKey<Value>) -> Bool {
        configs[ObjectIdentifier(key)] != nil
    }
    
}
