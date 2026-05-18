//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleKeyTests.swift
//  ModularSDK
//
//

import XCTest
import Core
@testable import ModularSDK

final class ModuleKeyTests: XCTestCase {

    func test_sameInstance_shouldBeEqual() {
        let key = ModuleKey<String>("test")
        XCTAssertEqual(key, key)
    }

    func test_differentInstances_sameName_shouldNotBeEqual() {
        let key1 = ModuleKey<String>("test")
        let key2 = ModuleKey<String>("test")

        XCTAssertNotEqual(key1, key2)
    }

    func test_hash_shouldBeDifferentForDifferentInstances() {
        let key1 = ModuleKey<String>("test")
        let key2 = ModuleKey<String>("test")

        XCTAssertNotEqual(key1.hashValue, key2.hashValue)
    }
}
