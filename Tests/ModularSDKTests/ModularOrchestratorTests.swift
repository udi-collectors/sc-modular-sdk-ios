//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModularOrchestratorTests.swift
//  ModularSDK
//
//

import XCTest
import Core
@testable import ModularSDK

struct EmptyConfig { }

final class MockModule<Output>: Module {

    typealias Config = EmptyConfig

    let key: ModuleKey<Output>

    var initializeCalled = false
    var startCollectCalled = false
    var startCollectSyncCalled = false
    var loadCollectorCalled = false
    var loadCollectorSyncCalled = false
    var configureCalled = false

    var endCollectResult: Output?
    var shouldThrow = false

    init(key: ModuleKey<Output>, result: Output? = nil) {
        self.key = key
        self.endCollectResult = result
    }

    func initialize() async {
        initializeCalled = true
    }

    func startCollect() async throws {
        startCollectCalled = true
    }
    
    func startCollectSync() throws {
        startCollectSyncCalled = true
    }

    func endCollect() -> Output? {
        if shouldThrow { return NSError(domain: "test", code: 1) as! Output }
        return endCollectResult
    }

    func configure(_ configure: EmptyConfig) async {
        configureCalled = true
    }
}
