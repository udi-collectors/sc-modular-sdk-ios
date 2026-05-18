//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleCollectionTests.swift
//  ModularSDK
//
//

import XCTest
import Core
@testable import ModularSDK

final class ModuleCollectionTests: XCTestCase {

    func test_insertAndGet_shouldReturnValue() throws {
        var collection = ModuleCollection()
        let key = ModuleKey<String>("key")

        collection.insert(key, value: "value")

        let result = try collection.get(key)?.get()
        XCTAssertEqual(result, "value")
    }

    func test_get_nonExistingKey_shouldReturnNil() {
        let collection = ModuleCollection()
        let key = ModuleKey<String>("key")

        XCTAssertNil(collection.get(key))
    }
}
