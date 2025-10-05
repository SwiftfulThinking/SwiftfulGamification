//
//  ProgressItem.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import SwiftData
import IdentifiableByString

/// Represents a single progress item tracked by a user
@Model
public final class ProgressItem: @unchecked Sendable, StringIdentifiable {
    /// Unique identifier for the progress item
    @Attribute(.unique) public var id: String

    /// Progress value between 0.0 and 1.0
    public var value: Double

    /// UTC timestamp when the progress item was created
    public var dateCreated: Date

    /// UTC timestamp when the progress item was last modified
    public var dateModified: Date

    // MARK: - Initialization

    public init(
        id: String,
        value: Double,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) {
        self.id = id
        self.value = value
        self.dateCreated = dateCreated
        self.dateModified = dateModified
    }

    // MARK: - Validation

    /// Validates that the progress data is within acceptable bounds
    public var isValid: Bool {
        isIdValid && isValueValid
    }

    /// Checks if ID is non-empty
    public var isIdValid: Bool {
        !id.isEmpty
    }

    /// Checks if value is between 0.0 and 1.0 (inclusive)
    public var isValueValid: Bool {
        value >= 0.0 && value <= 1.0
    }

    // MARK: - Mock Factory

    public static func mock(
        id: String = "progress_1",
        value: Double = 0.5,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) -> ProgressItem {
        ProgressItem(
            id: id,
            value: value,
            dateCreated: dateCreated,
            dateModified: dateModified
        )
    }
}

// MARK: - Codable Support

extension ProgressItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case value
        case dateCreated = "date_created"
        case dateModified = "date_modified"
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let value = try container.decode(Double.self, forKey: .value)
        let dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        let dateModified = try container.decode(Date.self, forKey: .dateModified)

        self.init(id: id, value: value, dateCreated: dateCreated, dateModified: dateModified)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(value, forKey: .value)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encode(dateModified, forKey: .dateModified)
    }
}

// MARK: - Analytics

extension ProgressItem {
    /// Event parameters formatted for analytics logging
    public var eventParameters: [String: Any] {
        [
            "progress_id": id,
            "progress_value": value,
            "progress_date_created": dateCreated.timeIntervalSince1970,
            "progress_date_modified": dateModified.timeIntervalSince1970
        ]
    }
}
