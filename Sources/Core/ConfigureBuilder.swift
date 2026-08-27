//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ConfigureBuilder.swift
//  ModularSDK
//
//

import Foundation

let defaultCollectTimeout: TimeInterval = 15

/// Type-safe runtime configuration builder used by the orchestrator.
///
/// `ConfigureBuilder` acts as a shared configuration container populated
/// by the orchestrator and consumed by modules during the configuration phase.
/// Configuration values are typically keyed using `ModuleKey` to ensure
/// strong typing at retrieval time.
public final class ConfigureBuilder {
    
    /// Global timeout value, expressed in seconds.
    ///
    /// Modules may choose to read or ignore this value depending
    /// on their specific configuration needs.
    public var timeout: TimeInterval = defaultCollectTimeout

    private var configs: [ObjectIdentifier: Any] = [:]

    public init() {
        // Configuration is added lazily through setConfig(for:config:).
    }
    
    /// Associates a configuration value with the given module key.
    ///
    /// The provided value is stored using the identity of the key and
    /// can later be retrieved by modules using the same `ModuleKey` instance.
    ///
    /// - Parameters:
    ///   - key: A typed module key identifying the configuration entry.
    ///   - config: The configuration value to associate with the key.
    public func setConfig<Value, Config>(
        for key: ConfigurableModuleKey<Value, Config>,
        config: Config?
    ) {
        if let value = config {
            configs[ObjectIdentifier(key)] = value
        } else {
            configs.removeValue(forKey: ObjectIdentifier(key))
        }
    }

    /// Associates an untyped configuration value with a plain module key.
    ///
    /// Use this escape hatch only for modules whose keys predate
    /// `ConfigurableModuleKey`. Configurable keys should use `setConfig` so
    /// the compiler can enforce their configuration type.
    public func setUntypedConfig<Value>(
        for key: ModuleKey<Value>,
        config: Any?
    ) {
        setRawConfig(for: key, config: config)
    }

    func setRawConfig<Value>(for key: ModuleKey<Value>, config: Any?) {
        if let value = config {
            configs[ObjectIdentifier(key)] = value
        } else {
            configs.removeValue(forKey: ObjectIdentifier(key))
        }
    }

    func getConfig<Value, Config>(for key: ModuleKey<Value>) -> Config? {
        configs[ObjectIdentifier(key)] as? Config
    }

    func hasConfig<Value>(for key: ModuleKey<Value>) -> Bool {
        configs[ObjectIdentifier(key)] != nil
    }
}
