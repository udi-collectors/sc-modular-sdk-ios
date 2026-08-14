//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleError.swift
//  ModularSDK
//
//

/// Typed errors describing why a module's configuration or collection failed.
public enum ModuleError: Error {

    /// No configuration was set for the module's key.
    case missingConfig(moduleKey: String)

    /// A configuration was set for the module's key but could not be cast
    /// to the type the module expects.
    case invalidConfig(moduleKey: String)

    /// The module itself reported a failure while configuring or collecting.
    case underlying(Error)
}

/// The result of a module operation, using `ModuleError` as its failure type.
public typealias ModuleResult<Value> = Result<Value, ModuleError>
