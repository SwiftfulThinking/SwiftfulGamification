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
///
/// **Storage Architecture:**
/// - `id`: User-provided identifier (e.g., "world1", "level5")
/// - `compositeId`: Internal composite key for SwiftData uniqueness ("{progressKey}_{id}")
/// - Firestore document path: `swiftful_progress/{userId}/{progressKey}/items/{id}`
/// - SwiftData uses `compositeId` as unique index to prevent conflicts across different progressKeys
@Model
public final class ProgressItem: @unchecked Sendable, StringIdentifiable {
    /// User-provided identifier (e.g., "world1", "level5")
    /// Used as Firestore document ID
    public var id: String

    /// Composite unique identifier for SwiftData: "{progressKey}_{id}"
    /// Prevents conflicts when same ID exists in different progressKeys
    @Attribute(.unique) public var compositeId: String

    /// Progress key for grouping items (e.g., "level", "achievements")
    public var progressKey: String

    /// Progress value between 0.0 and 1.0
    public var value: Double

    /// UTC timestamp when the progress item was created
    public var dateCreated: Date

    /// UTC timestamp when the progress item was last modified
    public var dateModified: Date

    /// Custom metadata associated with this item (for developer-defined data and filtering)
    public var metadata: [String: GamificationDictionaryValue]

    // MARK: - Initialization

    public init(
        id: String,
        progressKey: String,
        value: Double,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        metadata: [String: GamificationDictionaryValue] = [:]
    ) {
        self.id = id
        self.progressKey = progressKey
        self.compositeId = "\(progressKey)_\(id)"
        self.value = value
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.metadata = metadata
    }

    // MARK: - Validation

    /// Validates that the progress data is within acceptable bounds
    public var isValid: Bool {
        isIdValid && isValueValid && isMetadataValid
    }

    /// Checks if ID is non-empty
    public var isIdValid: Bool {
        !id.isEmpty
    }

    /// Checks if value is between 0.0 and 1.0 (inclusive)
    public var isValueValid: Bool {
        value >= 0.0 && value <= 1.0
    }

    /// Checks if metadata keys are safe for Firestore (alphanumeric + underscore only)
    public var isMetadataValid: Bool {
        let validKeyPattern = "^[a-zA-Z0-9_]+$"
        let regex = try? NSRegularExpression(pattern: validKeyPattern)

        for key in metadata.keys {
            let range = NSRange(location: 0, length: key.utf16.count)
            if regex?.firstMatch(in: key, range: range) == nil {
                return false
            }
        }
        return true
    }

    // MARK: - Mock Factory

    public static func mock(
        id: String = "progress_1",
        progressKey: String = "default",
        value: Double = 0.5,
        dateCreated: Date = Date(),
        dateModified: Date = Date()
    ) -> ProgressItem {
        ProgressItem(
            id: id,
            progressKey: progressKey,
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
        case compositeId = "composite_id"
        case progressKey = "progress_key"
        case value
        case dateCreated = "date_created"
        case dateModified = "date_modified"
        case metadata
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let progressKey = try container.decode(String.self, forKey: .progressKey)
        let value = try container.decode(Double.self, forKey: .value)
        let dateCreated = try container.decode(Date.self, forKey: .dateCreated)
        let dateModified = try container.decode(Date.self, forKey: .dateModified)
        let metadata = try container.decodeIfPresent([String: GamificationDictionaryValue].self, forKey: .metadata) ?? [:]

        self.init(id: id, progressKey: progressKey, value: value, dateCreated: dateCreated, dateModified: dateModified, metadata: metadata)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(compositeId, forKey: .compositeId)
        try container.encode(progressKey, forKey: .progressKey)
        try container.encode(value, forKey: .value)
        try container.encode(dateCreated, forKey: .dateCreated)
        try container.encode(dateModified, forKey: .dateModified)
        try container.encode(metadata, forKey: .metadata)
    }
}

// MARK: - Analytics

extension ProgressItem {
    /// Event parameters formatted for analytics logging
    public var eventParameters: [String: Any] {
        var params: [String: Any] = [
            "progress_id": id,
            "progress_composite_id": compositeId,
            "progress_key": progressKey,
            "progress_value": value,
            "progress_date_created": dateCreated.timeIntervalSince1970,
            "progress_date_modified": dateModified.timeIntervalSince1970,
            "progress_metadata_count": metadata.count
        ]

        // Add metadata values
        for (key, value) in metadata {
            params["progress_metadata_\(key)"] = value.anyValue
        }

        return params
    }
}
