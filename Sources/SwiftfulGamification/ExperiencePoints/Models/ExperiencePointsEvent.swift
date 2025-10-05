//
//  ExperiencePointsEvent.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import IdentifiableByString

/// Represents a single experience points event logged by a user
public struct ExperiencePointsEvent: StringIdentifiable, Codable, Sendable, Equatable {
    /// Unique identifier for the event
    public let id: String

    /// The experience ID this event belongs to (e.g., "main", "battle", "quest")
    public let experienceId: String

    /// UTC timestamp when the event occurred
    public let timestamp: Date

    /// Number of experience points earned in this event
    public let points: Int

    /// Custom metadata associated with this event (for developer-defined data and filtering)
    public let metadata: [String: GamificationDictionaryValue]

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        experienceId: String,
        timestamp: Date = Date(),
        points: Int,
        metadata: [String: GamificationDictionaryValue] = [:]
    ) {
        self.id = id
        self.experienceId = experienceId
        self.timestamp = timestamp
        self.points = points
        self.metadata = metadata
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case id
        case experienceId = "experience_id"
        case timestamp
        case points
        case metadata
    }

    // MARK: - Validation

    /// Validates that the event data is within acceptable bounds
    public var isValid: Bool {
        isIdValid && isTimestampValid && isMetadataValid && isPointsValid
    }

    /// Checks if ID is non-empty
    public var isIdValid: Bool {
        !id.isEmpty
    }

    /// Checks if points is non-negative
    public var isPointsValid: Bool {
        points >= 0
    }

    /// Checks if timestamp is not in the future and not older than 1 year
    public var isTimestampValid: Bool {
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        return timestamp <= now && timestamp >= oneYearAgo
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

    // MARK: - Analytics

    /// Event parameters formatted for analytics logging
    public var eventParameters: [String: Any] {
        var params: [String: Any] = [
            "xp_event_id": id,
            "xp_event_experience_id": experienceId,
            "xp_event_timestamp": timestamp.timeIntervalSince1970,
            "xp_event_points": points,
            "xp_event_metadata_count": metadata.count
        ]

        // Add metadata values
        for (key, value) in metadata {
            params["xp_event_metadata_\(key)"] = value.anyValue
        }

        return params
    }

    // MARK: - Mock Factory

    public static func mock(
        id: String = UUID().uuidString,
        experienceId: String = "main",
        timestamp: Date = Date(),
        points: Int = 100,
        metadata: [String: GamificationDictionaryValue] = ["source": "test"]
    ) -> Self {
        ExperiencePointsEvent(
            id: id,
            experienceId: experienceId,
            timestamp: timestamp,
            points: points,
            metadata: metadata
        )
    }

    /// Creates a mock event for a specific date
    public static func mock(
        date: Date,
        experienceId: String = "main",
        points: Int = 100,
        metadata: [String: GamificationDictionaryValue] = ["source": "test"]
    ) -> Self {
        ExperiencePointsEvent(
            id: UUID().uuidString,
            experienceId: experienceId,
            timestamp: date,
            points: points,
            metadata: metadata
        )
    }

    /// Creates a mock event X days ago
    public static func mock(
        daysAgo: Int,
        experienceId: String = "main",
        points: Int = 100,
        metadata: [String: GamificationDictionaryValue] = ["source": "test"]
    ) -> Self {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return mock(date: date, experienceId: experienceId, points: points, metadata: metadata)
    }
}
