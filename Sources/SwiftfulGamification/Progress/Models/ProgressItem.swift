//
//  ProgressItem.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import IdentifiableByString

/// Represents a single progress item tracked by a user
///
/// **Architecture Note:**
/// This is the public domain model used throughout the SwiftfulGamification API.
/// For SwiftData persistence, this converts to/from ProgressItemEntity in the persistence layer.
///
/// **Storage Architecture:**
/// - `id`: User-provided identifier (e.g., "World 1", "Level 5")
/// - `sanitizedId`: Database-safe identifier (e.g., "world_1", "level_5") - used for storage
/// - `compositeId`: Computed composite key ("{progressKey}_{sanitizedId}") for uniqueness
/// - Firestore document path: `swiftful_progress/{userId}/{progressKey}/items/{sanitizedId}`
public struct ProgressItem: Sendable, Codable, StringIdentifiable {
    /// User-provided identifier (e.g., "World 1", "Level 5")
    /// This is the original ID as provided by the user
    public let id: String

    /// Progress key for grouping items (e.g., "level", "achievements")
    public let progressKey: String

    /// Progress value between 0.0 and 1.0
    public let value: Double

    /// UTC timestamp when the progress item was created
    public let dateCreated: Date

    /// UTC timestamp when the progress item was last modified
    public let dateModified: Date

    /// Custom metadata associated with this item (for developer-defined data and filtering)
    public let metadata: [String: GamificationDictionaryValue]

    /// Sanitized identifier safe for database storage (e.g., "world_1", "level_5")
    /// This is what gets used as the Firestore document ID
    public var sanitizedId: String {
        id.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
    }

    /// Composite unique identifier: "{progressKey}_{sanitizedId}"
    /// Prevents conflicts when same ID exists in different progressKeys
    public var compositeId: String {
        "\(progressKey)_\(sanitizedId)"
    }

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

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case id
        case progressKey = "progress_key"
        case value
        case dateCreated = "date_created"
        case dateModified = "date_modified"
        case metadata
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
