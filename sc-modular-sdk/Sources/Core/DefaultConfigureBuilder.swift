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
    private(set) var configs: [ObjectIdentifier: Any?] = [:]
    
    /// Associates a configuration value with the given module key.
    ///
    /// This method allows storing arbitrary configuration data that can
    /// later be retrieved by modules using the same `ModuleKey` instance.
    ///
    /// - Parameters:
    ///   - key: A typed `ModuleKey` identifying the configuration entry.
    ///   - config: The configuration value to associate with the key.
    public func setConfig<Value>(
        for key: ModuleKey<Value>,
        config: Any?
    ) {
        configs[ObjectIdentifier(key)] = config
    }
    
    /// Retrieves the configuration value associated with the given module key.
    ///
    /// The returned value must be cast by the caller to the expected type.
    ///
    /// - Parameter key: A typed `ModuleKey` identifying the configuration entry.
    /// - Returns: The stored configuration value, or `nil` if no value
    ///   has been associated with the key.
    public func getConfig<Value, Config>(for key: ModuleKey<Value>) -> Config? {
        configs[ObjectIdentifier(key)] as? Config
    }
    
}
