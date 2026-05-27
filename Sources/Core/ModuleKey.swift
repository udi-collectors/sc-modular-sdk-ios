//  Copyright (c) Experian, 2026. All rights reserved.
//
//  ModuleKey.swift
//  ModularSDK
//
//

/// A unique, strongly-typed identifier used to index module results and configurations.
///
/// `ModuleKey` provides identity-based equality and hashing, ensuring that
/// each key instance is unique even if multiple keys share the same name.
/// This design enables type-safe storage and retrieval of heterogeneous values
/// within containers such as `ModuleCollection` and `ConfigureBuilder`.
public class ModuleKey<Value>: Hashable {
    
    /// A human-readable name for the module key.
    ///
    /// This value is intended for debugging and diagnostics purposes only
    /// and is not used for equality or hashing.
    public let name: String
    
    /// Creates a new module key with the given name.
    ///
    /// - Parameter name: A descriptive name for the key, used for
    ///   identification during debugging.
    public init(_ name: String) {
        self.name = name
    }
    
    /// Determines equality based on object identity.
    ///
    /// Two `ModuleKey` instances are considered equal only if they
    /// reference the exact same object instance.
    public static func == (lhs: ModuleKey<Value>, rhs: ModuleKey<Value>) -> Bool {
        lhs === rhs
    }
    
    /// Hashes the key using its object identity.
    ///
    /// This ensures consistency with the identity-based equality check
    /// and allows safe usage as a dictionary key.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
