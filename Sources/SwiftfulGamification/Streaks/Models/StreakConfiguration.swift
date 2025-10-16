//
//  StreakConfiguration.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

/// Freeze behavior options for streak management
public enum FreezeBehavior: String, Codable, Sendable {
    /// No freeze functionality
    case noFreezes
    /// Automatically consume freezes when streak would break
    case autoConsumeFreezes
    /// Freezes must be manually consumed by user
    case manuallyConsumeFreezes
}

/// Result of manual freeze usage
public enum UseFreezesResult: Sendable {
    /// Freezes were used and streak was saved
    case didUseFreezesAndSavedStreak
    /// No freezes were used (streak not at risk or no freezes available)
    case didNotUseFreezes
}

/// Status for applying manual streak freezes
public enum ApplyManualStreakFreezeStatus: Sendable, Equatable {
    /// User can save streak by using the specified number of freezes (and has enough available)
    case canSaveStreakWithFreezes(count: Int)
    /// User cannot save streak (either streak is active or not enough freezes available)
    case cannotSaveStreakWithFreezes
}

/// Configuration for streak behavior
public struct StreakConfiguration: Codable, Sendable, Equatable {
    /// Streak identifier (e.g., "workout", "reading")
    public let streakKey: String

    /// Number of events required per day to maintain streak (1 = basic streak, >1 = goal-based)
    public let eventsRequiredPerDay: Int

    /// Use server-side calculation instead of client-side
    public let useServerCalculation: Bool

    /// Grace period in hours around midnight (0 = strict, ±X hours = lenient)
    public let leewayHours: Int

    /// Freeze behavior for streak management
    public let freezeBehavior: FreezeBehavior

    // MARK: - Initialization

    public init(
        streakKey: String,
        eventsRequiredPerDay: Int = 1,
        useServerCalculation: Bool = false,
        leewayHours: Int = 0,
        freezeBehavior: FreezeBehavior = .manuallyConsumeFreezes
    ) {
        precondition(
            streakKey == streakKey.sanitizeForDatabaseKeysByRemovingWhitespaceAndSpecialCharacters(),
            "streakKey must be sanitized (no whitespace, no special characters)"
        )
        precondition(eventsRequiredPerDay >= 1, "eventsRequiredPerDay must be >= 1")
        precondition(leewayHours >= 0, "leewayHours must be >= 0")
        precondition(leewayHours <= 24, "leewayHours must be <= 24")

        self.streakKey = streakKey
        self.eventsRequiredPerDay = eventsRequiredPerDay
        self.useServerCalculation = useServerCalculation
        self.leewayHours = leewayHours
        self.freezeBehavior = freezeBehavior
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case streakKey = "streak_id"
        case eventsRequiredPerDay = "events_required_per_day"
        case useServerCalculation = "use_server_calculation"
        case leewayHours = "leeway_hours"
        case freezeBehavior = "freeze_behavior"
    }

    // MARK: - Computed Properties

    /// Is this a goal-based streak (requires multiple events per day)?
    public var isGoalBasedStreak: Bool {
        eventsRequiredPerDay > 1
    }

    /// Is this strict mode (no grace period)?
    public var isStrictMode: Bool {
        leewayHours == 0
    }

    /// Is this travel-friendly (large grace period)?
    public var isTravelFriendly: Bool {
        leewayHours >= 12
    }

    // MARK: - Mock Factory

    public static func mock(
        streakKey: String = "workout",
        eventsRequiredPerDay: Int = 1,
        useServerCalculation: Bool = false,
        leewayHours: Int = 0,
        freezeBehavior: FreezeBehavior = .manuallyConsumeFreezes
    ) -> Self {
        StreakConfiguration(
            streakKey: streakKey,
            eventsRequiredPerDay: eventsRequiredPerDay,
            useServerCalculation: useServerCalculation,
            leewayHours: leewayHours,
            freezeBehavior: freezeBehavior
        )
    }

    /// Mock for basic streak (default settings)
    public static func mockDefault(streakKey: String = "workout") -> Self {
        StreakConfiguration(
            streakKey: streakKey,
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 0,
            freezeBehavior: .manuallyConsumeFreezes
        )
    }

    /// Mock for goal-based streak
    public static func mockGoalBased(streakKey: String = "workout", eventsRequiredPerDay: Int = 3) -> Self {
        StreakConfiguration(
            streakKey: streakKey,
            eventsRequiredPerDay: eventsRequiredPerDay,
            useServerCalculation: false,
            leewayHours: 0,
            freezeBehavior: .manuallyConsumeFreezes
        )
    }

    /// Mock for lenient streak (with grace period)
    public static func mockLenient(streakKey: String = "workout", leewayHours: Int = 3) -> Self {
        StreakConfiguration(
            streakKey: streakKey,
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: leewayHours,
            freezeBehavior: .manuallyConsumeFreezes
        )
    }

    /// Mock for travel-friendly streak
    public static func mockTravelFriendly(streakKey: String = "workout") -> Self {
        StreakConfiguration(
            streakKey: streakKey,
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 24,
            freezeBehavior: .manuallyConsumeFreezes
        )
    }

    /// Mock with server-side calculation enabled
    public static func mockServerCalculation(streakKey: String = "workout") -> Self {
        StreakConfiguration(
            streakKey: streakKey,
            eventsRequiredPerDay: 1,
            useServerCalculation: true,
            leewayHours: 0,
            freezeBehavior: .manuallyConsumeFreezes
        )
    }
}
