//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleCollection.swift
//  ModularSDK
//
//

/// A type-safe container used to aggregate results produced by modules.
///
/// `ModuleCollection` stores values keyed by `ModuleKey` identity and
/// allows consumers to retrieve results in a strongly-typed manner.
/// It is typically populated by `ModularOrchestrator` during `endCollect()`.

public struct ModuleCollection {
    
    // MARK: - Storage
    
    /// Internal storage for collected module results.
    /// Stores both success and failure using `Result<Value, Error>`.
    private var storage: [ObjectIdentifier: Any] = [:]
    
    public init() {}
    
    // MARK: - Insert Success
    
    public mutating func insert<Value>(
        _ key: ModuleKey<Value>,
        value: Value
    ) {
        storage[ObjectIdentifier(key)] = Result<Value, Error>.success(value)
    }
    
    // MARK: - Insert Failure
    
    public mutating func insertError<Value>(
        _ key: ModuleKey<Value>,
        error: Error
    ) {
        storage[ObjectIdentifier(key)] = Result<Value, Error>.failure(error)
    }
    
    // MARK: - Get Result
    
    public func get<Value>(
        _ key: ModuleKey<Value>
    ) -> Result<Value, Error>? {
        storage[ObjectIdentifier(key)] as? Result<Value, Error>
    }
    
    // MARK: - Subscript (Swifty API)
    
    public subscript<Value>(
        key: ModuleKey<Value>
    ) -> Result<Value, Error>? {
        storage[ObjectIdentifier(key)] as? Result<Value, Error>
    }
    
    // MARK: - Convenience (Value Only)
    
    public func value<Value>(
        _ key: ModuleKey<Value>
    ) -> Value? {
        guard let result = storage[ObjectIdentifier(key)] as? Result<Value, Error> else {
            return nil
        }
        return try? result.get()
    }
    
    // MARK: - Convenience (Error Only)
    
    public func error<Value>(
        _ key: ModuleKey<Value>
    ) -> Error? {
        guard let result = storage[ObjectIdentifier(key)] as? Result<Value, Error> else {
            return nil
        }
        
        if case .failure(let error) = result {
            return error
        }
        
        return nil
    }
}
