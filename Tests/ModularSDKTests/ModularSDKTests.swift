//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModularSDKTests.swift
//  ModularSDK
//
//

import XCTest
import Core
@testable import ModularSDK

// MARK: - Test Helpers

private var collectorCalled = false
private var diCollectorCalled = false

private func collectorFunction() {
    collectorCalled = true
}

private func diCollectorFunction() {
    diCollectorCalled = true
}

final class ModulesLoaderTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        ModulesLoader.modulesLoaded = []
        collectorCalled = false
        diCollectorCalled = false
    }
    
    override func tearDown() {
        ModulesLoader.resolver = { handle, symbol in
            dlsym(handle, symbol)
        }
        super.tearDown()
    }
    
    func test_start_shouldLoadAvailableModules() {
        // Given
        ModulesLoader.resolver = { _, symbol in
            switch symbol {
            case "load_collector":
                return unsafeBitCast(
                    collectorFunction as ModuleLoaderFunc,
                    to: UnsafeMutableRawPointer.self
                )
            case "load_di_collector":
                return unsafeBitCast(
                    diCollectorFunction as ModuleLoaderFunc,
                    to: UnsafeMutableRawPointer.self
                )
            default:
                return nil
            }
        }
        
        // When
        ModulesLoader.start()
        
        // Then
        XCTAssertTrue(collectorCalled)
        XCTAssertTrue(diCollectorCalled)
        XCTAssertEqual(ModulesLoader.modulesLoaded.count, 2)
        XCTAssertTrue(ModulesLoader.modulesLoaded.contains("load_collector"))
        XCTAssertTrue(ModulesLoader.modulesLoaded.contains("load_di_collector"))
    }
    
    func test_start_shouldNotLoadModules_whenSymbolNotFound() {
        // Given
        ModulesLoader.resolver = { _, _ in nil }
        
        // When
        ModulesLoader.start()
        
        // Then
        XCTAssertTrue(ModulesLoader.modulesLoaded.isEmpty)
    }
    
    func test_defaultResolver_shouldReturnNil_whenSymbolDoesNotExist() {
    // Given
        let resolver = ModulesLoader.resolver

        // When
        let result = resolver(UnsafeMutableRawPointer(bitPattern: -2), "non_existing_symbol_123")

        // Then
        XCTAssertNil(result)
    }
}
