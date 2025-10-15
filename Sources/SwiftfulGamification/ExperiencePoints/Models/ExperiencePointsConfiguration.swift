//
//  ExperiencePointsConfiguration.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

/// Configuration for experience points behavior
public struct ExperiencePointsConfiguration: Codable, Sendable, Equatable {
    /// Experience identifier (e.g., "main", "battle", "quest")
    public let experienceKey: String

    /// Enable server-side calculation via Cloud Function (requires Firebase deployment)
    public let useServerCalculation: Bool

    // MARK: - Initialization

    public init(
        experienceKey: String,
        useServerCalculation: Bool = false
    ) {
        precondition(
            experienceKey == experienceKey.sanitizeForDatabaseKeysByRemovingWhitespaceAndSpecialCharacters(),
            "experienceKey must be sanitized (no whitespace, no special characters)"
        )

        self.experienceKey = experienceKey
        self.useServerCalculation = useServerCalculation
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case experienceKey = "experience_id"
        case useServerCalculation = "use_server_calculation"
    }

    // MARK: - Mock Factory

    public static func mock(
        experienceKey: String = "main",
        useServerCalculation: Bool = false
    ) -> Self {
        ExperiencePointsConfiguration(
            experienceKey: experienceKey,
            useServerCalculation: useServerCalculation
        )
    }

    /// Mock for basic configuration (default settings)
    public static func mockDefault(experienceKey: String = "main") -> Self {
        ExperiencePointsConfiguration(
            experienceKey: experienceKey,
            useServerCalculation: false
        )
    }

    /// Mock with server-side calculation enabled
    public static func mockServerCalculation(experienceKey: String = "main") -> Self {
        ExperiencePointsConfiguration(
            experienceKey: experienceKey,
            useServerCalculation: true
        )
    }
}
