//  Copyright (c) Experian, 2026. All rights reserved.
//
//  Core.swift
//  ModularSDK
//

@_exported import Core

/**
 * Public entry type for the Modular SDK product.
 *
 * Re-exports `Core` so consumers can `import ModularSDK` and use orchestrator APIs.
 */
public struct ModularSDK {

    @discardableResult
    public static func start() -> ModuleLoadingResult {
        ModulesLoader.start()
    }
}
