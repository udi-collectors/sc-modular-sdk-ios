//  Copyright (c) Experian, 2026. All rights reserved.
//
//  DefaultConfigureBuilderTests.swift
//  ModularSDK
//
//

import XCTest
import Core
@testable import ModularSDK

final class DefaultConfigureBuilderTests: XCTestCase {
    
    func test_timeout_defaultValue_shouldBe15() {
        let builder = DefaultConfigureBuilder()
        XCTAssertEqual(builder.timeout, 15)
    }

}
