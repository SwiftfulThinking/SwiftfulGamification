//
//  ProgressConfiguration.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-07.
//

import Foundation

/// Configuration for progress behavior
public struct ProgressConfiguration: Codable, Sendable, Equatable {
    /// Progress key for grouping items (e.g., "level", "achievements", "quests")
    public let progressKey: String

    // MARK: - Initialization

    public init(
        progressKey: String
    ) {
        precondition(
            progressKey == progressKey.sanitizeForDatabaseKeysByRemovingWhitespaceAndSpecialCharacters(),
            "progressKey must be sanitized (no whitespace, no special characters)"
        )

        self.progressKey = progressKey
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case progressKey = "progress_key"
    }

    // MARK: - Mock Factory

    public static func mock(
        progressKey: String = "default"
    ) -> Self {
        ProgressConfiguration(
            progressKey: progressKey
        )
    }

    /// Mock for default configuration
    public static func mockDefault() -> Self {
        ProgressConfiguration(
            progressKey: "default"
        )
    }

    /// Mock for level progress
    public static func mockLevel() -> Self {
        ProgressConfiguration(
            progressKey: "level"
        )
    }

    /// Mock for achievements progress
    public static func mockAchievements() -> Self {
        ProgressConfiguration(
            progressKey: "achievements"
        )
    }
}
