//
//  GamificationDictionaryValue.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

/// Type-safe value container for event metadata
/// Supports only Firestore-compatible types: String, Bool, Int, Double, Float, CGFloat
///
/// Usage:
/// ```swift
/// let metadata: [String: GamificationDictionaryValue] = [
///     "workout_type": "cardio",    // String literal
///     "reps": 50,                  // Int literal
///     "completed": true,           // Bool literal
///     "distance": 5.2,             // Double literal
///     "weight": Float(185.5)       // Float (explicit)
/// ]
/// ```
public enum GamificationDictionaryValue: Codable, Sendable, Equatable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case float(Float)
    case cgFloat(CGFloat)

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum ValueType: String, Codable {
        case string
        case bool
        case int
        case double
        case float
        case cgFloat
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)

        switch type {
        case .string:
            let value = try container.decode(String.self, forKey: .value)
            self = .string(value)
        case .bool:
            let value = try container.decode(Bool.self, forKey: .value)
            self = .bool(value)
        case .int:
            let value = try container.decode(Int.self, forKey: .value)
            self = .int(value)
        case .double:
            let value = try container.decode(Double.self, forKey: .value)
            self = .double(value)
        case .float:
            let value = try container.decode(Float.self, forKey: .value)
            self = .float(value)
        case .cgFloat:
            let value = try container.decode(CGFloat.self, forKey: .value)
            self = .cgFloat(value)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let value):
            try container.encode(ValueType.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode(ValueType.bool, forKey: .type)
            try container.encode(value, forKey: .value)
        case .int(let value):
            try container.encode(ValueType.int, forKey: .type)
            try container.encode(value, forKey: .value)
        case .double(let value):
            try container.encode(ValueType.double, forKey: .type)
            try container.encode(value, forKey: .value)
        case .float(let value):
            try container.encode(ValueType.float, forKey: .type)
            try container.encode(value, forKey: .value)
        case .cgFloat(let value):
            try container.encode(ValueType.cgFloat, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }

    // MARK: - Helpers

    /// Extract the underlying value as Any
    public var anyValue: Any {
        switch self {
        case .string(let value): return value
        case .bool(let value): return value
        case .int(let value): return value
        case .double(let value): return value
        case .float(let value): return value
        case .cgFloat(let value): return value
        }
    }
}

// MARK: - ExpressibleBy Protocols

extension GamificationDictionaryValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension GamificationDictionaryValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension GamificationDictionaryValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension GamificationDictionaryValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}
