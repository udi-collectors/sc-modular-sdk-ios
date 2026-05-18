//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleBoxTests.swift
//  ModularSDK
//
//

import XCTest
import Core
@testable import ModularSDK

final class ModuleBoxTests: XCTestCase {

    func test_collect_nilValue_shouldNotInsert() async throws {
        let key = ModuleKey<String>("key")
        let module = MockModule<String>(key: key, result: nil)
        let box = ModuleBox(module)

        var collection = ModuleCollection()
        await box.collect(into: &collection)

        XCTAssertNil(collection.get(key))
    }

    func test_startCollect_shouldCallUnderlyingModule() async throws {
        let module = MockModule(key: ModuleKey<String>("key"))
        let box = ModuleBox(module)

        try await box.startCollect()

        XCTAssertTrue(module.startCollectCalled)
    }

    func test_initialize_shouldCallUnderlyingModule() async {
        let module = MockModule(key: ModuleKey<String>("key"))
        let box = ModuleBox(module)

        await box.initialize()

        XCTAssertTrue(module.initializeCalled)
    }
}
