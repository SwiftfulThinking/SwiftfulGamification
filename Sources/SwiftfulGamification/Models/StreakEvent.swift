//
//  StreakEvent.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

/// Represents a single streak event logged by a user
public struct StreakEvent: Identifiable, Codable, Sendable, Equatable {
    /// Unique identifier for the event
    public let id: String

    /// UTC timestamp when the event occurred
    public let timestamp: Date

    /// Timezone identifier where the event was logged (e.g., "America/New_York")
    public let timezone: String

    /// Custom metadata associated with this event
    public let metadata: [String: GamificationDictionaryValue]

    // MARK: - Initialization

    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        timezone: String = TimeZone.current.identifier,
        metadata: [String: GamificationDictionaryValue] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.timezone = timezone
        self.metadata = metadata
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case timezone
        case metadata
    }

    // MARK: - Validation

    /// Validates that the event data is within acceptable bounds
    public var isValid: Bool {
        isIdValid && isTimestampValid && isTimezoneValid && isMetadataValid
    }

    /// Checks if ID is non-empty
    public var isIdValid: Bool {
        !id.isEmpty
    }

    /// Checks if timestamp is not in the future and not older than 1 year
    public var isTimestampValid: Bool {
        let now = Date()
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        return timestamp <= now && timestamp >= oneYearAgo
    }

    /// Checks if timezone is a valid TimeZone identifier
    public var isTimezoneValid: Bool {
        TimeZone(identifier: timezone) != nil
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
            "event_id": id,
            "timestamp": timestamp.timeIntervalSince1970,
            "timezone": timezone,
            "metadata_count": metadata.count
        ]

        // Add metadata values
        for (key, value) in metadata {
            params["metadata_\(key)"] = value.anyValue
        }

        return params
    }

    // MARK: - Mock Factory

    public static func mock(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        timezone: String = TimeZone.current.identifier,
        metadata: [String: GamificationDictionaryValue] = ["action": "test"]
    ) -> Self {
        StreakEvent(
            id: id,
            timestamp: timestamp,
            timezone: timezone,
            metadata: metadata
        )
    }

    /// Creates a mock event for a specific date in a timezone
    public static func mock(
        date: Date,
        timezone: String = TimeZone.current.identifier,
        metadata: [String: GamificationDictionaryValue] = ["action": "test"]
    ) -> Self {
        StreakEvent(
            id: UUID().uuidString,
            timestamp: date,
            timezone: timezone,
            metadata: metadata
        )
    }

    /// Creates a mock event X days ago
    public static func mock(
        daysAgo: Int,
        timezone: String = TimeZone.current.identifier,
        metadata: [String: GamificationDictionaryValue] = ["action": "test"]
    ) -> Self {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return mock(date: date, timezone: timezone, metadata: metadata)
    }
}
