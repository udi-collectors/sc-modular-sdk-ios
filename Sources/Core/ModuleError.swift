//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleError.swift
//  ModularSDK
//
//

/// Typed errors describing why a module's configuration or collection failed.
public enum ModuleError: Error {

    /// A known collector module could not be loaded into the process.
    case moduleUnavailable(moduleKey: String, symbol: String)

    /// No configuration was set for the module's key.
    case missingConfig(moduleKey: String)

    /// A configuration was set for the module's key but could not be cast
    /// to the type the module expects.
    case invalidConfig(moduleKey: String)

    /// `configure` was called while the module was in a lifecycle state that
    /// does not allow configuration (only `.collecting` — `.notConfigured`,
    /// `.configured`, and `.collected` are all valid entry states).
    case invalidLifecycleState(moduleKey: String, state: ModuleLifecycleState)

    /// `startCollect` was called on a module that requires configuration
    /// (neither `Void` nor `NoConfig`) while it was still `.notConfigured`.
    case notConfigured(moduleKey: String)

    /// `collect` was called while the module was not currently collecting.
    case notCollecting(moduleKey: String)

    /// The module's `startCollect` did not complete within the configured timeout.
    case timeout(moduleKey: String)

    /// The module itself reported a failure while configuring or collecting.
    case underlying(Error)
}

/// The result of a module operation, using `ModuleError` as its failure type.
public typealias ModuleResult<Value> = Result<Value, ModuleError>
