//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleLifecycleState.swift
//  ModularSDK
//
//

/// The lifecycle state of a wrapped module, tracked by `ModuleBox`.
public enum ModuleLifecycleState: Equatable {
    case notConfigured
    case configured
    case collecting
    case collected
}
