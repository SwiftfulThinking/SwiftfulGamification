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
    public let experienceId: String

    /// Enable server-side calculation via Cloud Function (requires Firebase deployment)
    public let useServerCalculation: Bool

    // MARK: - Initialization

    public init(
        experienceId: String,
        useServerCalculation: Bool = false
    ) {
        self.experienceId = experienceId
        self.useServerCalculation = useServerCalculation
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case experienceId = "experience_id"
        case useServerCalculation = "use_server_calculation"
    }

    // MARK: - Mock Factory

    public static func mock(
        experienceId: String = "main",
        useServerCalculation: Bool = false
    ) -> Self {
        ExperiencePointsConfiguration(
            experienceId: experienceId,
            useServerCalculation: useServerCalculation
        )
    }

    /// Mock for basic configuration (default settings)
    public static func mockBasic(experienceId: String = "main") -> Self {
        ExperiencePointsConfiguration(
            experienceId: experienceId,
            useServerCalculation: false
        )
    }

    /// Mock with server-side calculation enabled
    public static func mockServerCalculation(experienceId: String = "main") -> Self {
        ExperiencePointsConfiguration(
            experienceId: experienceId,
            useServerCalculation: true
        )
    }
}
