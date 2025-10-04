//
//  CurrentStreakData.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

/// Represents a user's current streak status
public struct CurrentStreakData: Identifiable, Codable, Sendable, Equatable {
    /// Unique identifier (typically userId)
    public let id: String

    /// Streak identifier (e.g., "workout", "reading")
    public let streakId: String?

    /// Current consecutive streak count
    public let currentStreak: Int?

    /// All-time longest streak achieved
    public let longestStreak: Int?

    /// UTC timestamp of last event
    public let lastEventDate: Date?

    /// Timezone identifier of last event
    public let lastEventTimezone: String?

    /// UTC timestamp when current streak started
    public let streakStartDate: Date?

    /// Total number of events logged
    public let totalEvents: Int?

    /// Number of streak freezes remaining
    public let freezesRemaining: Int?

    /// UTC timestamp of first event ever
    public let createdAt: Date?

    /// UTC timestamp of last update
    public let updatedAt: Date?

    /// Goal-based: number of events required per day (1 = basic streak)
    public let eventsRequiredPerDay: Int?

    /// Goal-based: number of events logged today
    public let todayEventCount: Int?

    // MARK: - Initialization

    public init(
        id: String,
        streakId: String? = nil,
        currentStreak: Int? = nil,
        longestStreak: Int? = nil,
        lastEventDate: Date? = nil,
        lastEventTimezone: String? = nil,
        streakStartDate: Date? = nil,
        totalEvents: Int? = nil,
        freezesRemaining: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        eventsRequiredPerDay: Int? = nil,
        todayEventCount: Int? = nil
    ) {
        self.id = id
        self.streakId = streakId
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastEventDate = lastEventDate
        self.lastEventTimezone = lastEventTimezone
        self.streakStartDate = streakStartDate
        self.totalEvents = totalEvents
        self.freezesRemaining = freezesRemaining
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.eventsRequiredPerDay = eventsRequiredPerDay
        self.todayEventCount = todayEventCount
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case id
        case streakId = "streak_id"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastEventDate = "last_event_date"
        case lastEventTimezone = "last_event_timezone"
        case streakStartDate = "streak_start_date"
        case totalEvents = "total_events"
        case freezesRemaining = "freezes_remaining"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case eventsRequiredPerDay = "events_required_per_day"
        case todayEventCount = "today_event_count"
    }

    // MARK: - Computed Properties

    /// Is the streak currently active (last event was today or yesterday)?
    public var isStreakActive: Bool {
        guard let lastEventDate = lastEventDate else { return false }
        guard let daysSince = daysSinceLastEvent else { return false }
        return daysSince <= 1
    }

    /// Is the streak at risk (last event was yesterday)?
    public var isStreakAtRisk: Bool {
        guard let daysSince = daysSinceLastEvent else { return false }
        return daysSince == 1
    }

    /// Number of days since last event (in user's current timezone)
    public var daysSinceLastEvent: Int? {
        guard let lastEventDate = lastEventDate else { return nil }

        let calendar = Calendar.current
        let now = Date()

        let lastDay = calendar.startOfDay(for: lastEventDate)
        let today = calendar.startOfDay(for: now)

        let components = calendar.dateComponents([.day], from: lastDay, to: today)
        return components.day
    }

    /// Goal-based: Has today's goal been met?
    public var isGoalMet: Bool {
        guard let required = eventsRequiredPerDay, required > 1 else {
            // Basic streak mode: any event counts
            return (todayEventCount ?? 0) >= 1
        }
        return (todayEventCount ?? 0) >= required
    }

    /// Goal-based: Progress toward today's goal (0.0 - 1.0)
    public var goalProgress: Double {
        let required = Double(eventsRequiredPerDay ?? 1)
        let current = Double(todayEventCount ?? 0)
        return min(current / required, 1.0)
    }

    // MARK: - Validation

    /// Validates data integrity
    public var isValid: Bool {
        // All Int values must be >= 0
        if let current = currentStreak, current < 0 { return false }
        if let longest = longestStreak, longest < 0 { return false }
        if let total = totalEvents, total < 0 { return false }
        if let freezes = freezesRemaining, freezes < 0 { return false }
        if let required = eventsRequiredPerDay, required < 1 { return false }
        if let today = todayEventCount, today < 0 { return false }

        // longestStreak >= currentStreak
        if let current = currentStreak, let longest = longestStreak {
            if longest < current { return false }
        }

        // Valid timezone if present
        if let tz = lastEventTimezone {
            if TimeZone(identifier: tz) == nil { return false }
        }

        return true
    }

    // MARK: - Analytics

    /// Event parameters for analytics logging
    public var eventParameters: [String: Any] {
        var params: [String: Any] = [
            "user_id": id
        ]

        if let streakId = streakId { params["streak_id"] = streakId }
        if let current = currentStreak { params["current_streak"] = current }
        if let longest = longestStreak { params["longest_streak"] = longest }
        if let total = totalEvents { params["total_events"] = total }
        if let freezes = freezesRemaining { params["freezes_remaining"] = freezes }
        if let required = eventsRequiredPerDay { params["events_required_per_day"] = required }
        if let today = todayEventCount { params["today_event_count"] = today }

        params["is_streak_active"] = isStreakActive
        params["is_goal_met"] = isGoalMet
        params["goal_progress"] = goalProgress

        return params
    }

    // MARK: - Mock Factory

    public static func mock(
        id: String = "user123",
        streakId: String = "workout",
        currentStreak: Int = 5,
        longestStreak: Int = 10,
        lastEventDate: Date = Date(),
        lastEventTimezone: String = TimeZone.current.identifier,
        streakStartDate: Date? = Calendar.current.date(byAdding: .day, value: -5, to: Date()),
        totalEvents: Int = 25,
        freezesRemaining: Int = 2,
        createdAt: Date? = Calendar.current.date(byAdding: .month, value: -1, to: Date()),
        updatedAt: Date = Date(),
        eventsRequiredPerDay: Int = 1,
        todayEventCount: Int = 1
    ) -> Self {
        CurrentStreakData(
            id: id,
            streakId: streakId,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastEventDate: lastEventDate,
            lastEventTimezone: lastEventTimezone,
            streakStartDate: streakStartDate,
            totalEvents: totalEvents,
            freezesRemaining: freezesRemaining,
            createdAt: createdAt,
            updatedAt: updatedAt,
            eventsRequiredPerDay: eventsRequiredPerDay,
            todayEventCount: todayEventCount
        )
    }

    /// Blank streak data (no events, zero streak)
    public static func blank(id: String) -> Self {
        CurrentStreakData(
            id: id,
            currentStreak: 0,
            longestStreak: 0,
            totalEvents: 0,
            freezesRemaining: 0,
            eventsRequiredPerDay: 1,
            todayEventCount: 0
        )
    }

    /// Mock with no events
    public static func mockEmpty(id: String = "user123", streakId: String = "workout") -> Self {
        CurrentStreakData(
            id: id,
            streakId: streakId,
            currentStreak: 0,
            longestStreak: 0,
            totalEvents: 0,
            freezesRemaining: 0,
            eventsRequiredPerDay: 1,
            todayEventCount: 0
        )
    }

    /// Mock with active streak
    public static func mockActive(
        id: String = "user123",
        streakId: String = "workout",
        currentStreak: Int = 7
    ) -> Self {
        CurrentStreakData(
            id: id,
            streakId: streakId,
            currentStreak: currentStreak,
            longestStreak: max(currentStreak, 10),
            lastEventDate: Date(),
            lastEventTimezone: TimeZone.current.identifier,
            streakStartDate: Calendar.current.date(byAdding: .day, value: -currentStreak, to: Date()),
            totalEvents: currentStreak + 5,
            freezesRemaining: 2,
            createdAt: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            updatedAt: Date(),
            eventsRequiredPerDay: 1,
            todayEventCount: 1
        )
    }

    /// Mock with streak at risk (yesterday was last event)
    public static func mockAtRisk(
        id: String = "user123",
        streakId: String = "workout",
        currentStreak: Int = 5
    ) -> Self {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return CurrentStreakData(
            id: id,
            streakId: streakId,
            currentStreak: currentStreak,
            longestStreak: max(currentStreak, 8),
            lastEventDate: yesterday,
            lastEventTimezone: TimeZone.current.identifier,
            streakStartDate: Calendar.current.date(byAdding: .day, value: -currentStreak, to: yesterday),
            totalEvents: currentStreak + 3,
            freezesRemaining: 1,
            createdAt: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            updatedAt: yesterday,
            eventsRequiredPerDay: 1,
            todayEventCount: 0
        )
    }

    /// Mock with goal-based streak
    public static func mockGoalBased(
        id: String = "user123",
        streakId: String = "workout",
        eventsRequiredPerDay: Int = 3,
        todayEventCount: Int = 1
    ) -> Self {
        CurrentStreakData(
            id: id,
            streakId: streakId,
            currentStreak: 4,
            longestStreak: 7,
            lastEventDate: Date(),
            lastEventTimezone: TimeZone.current.identifier,
            streakStartDate: Calendar.current.date(byAdding: .day, value: -4, to: Date()),
            totalEvents: 15,
            freezesRemaining: 2,
            createdAt: Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date()),
            updatedAt: Date(),
            eventsRequiredPerDay: eventsRequiredPerDay,
            todayEventCount: todayEventCount
        )
    }
}
