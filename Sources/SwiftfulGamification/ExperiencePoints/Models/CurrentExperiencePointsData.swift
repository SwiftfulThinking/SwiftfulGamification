//
//  CurrentExperiencePointsData.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

/// Represents a user's current experience points status
public struct CurrentExperiencePointsData: Identifiable, Codable, Sendable, Equatable {
    /// Identifiable conformance - uses experienceKey
    public var id: String {
        experienceKey
    }

    /// Experience identifier (e.g., "main", "battle", "quest")
    public let experienceKey: String

    /// User identifier
    public let userId: String?

    /// Total experience points accumulated
    public let totalPoints: Int?

    /// Total number of XP events logged
    public let totalEvents: Int?

    /// Number of XP events logged today
    public let todayEventCount: Int?

    /// UTC timestamp of last event
    public let lastEventDate: Date?

    /// UTC timestamp of first event ever
    public let createdAt: Date?

    /// UTC timestamp of last update
    public let updatedAt: Date?

    /// Recent events for display (last 60 days)
    public let recentEvents: [ExperiencePointsEvent]?

    // MARK: - Initialization

    public init(
        experienceKey: String,
        userId: String? = nil,
        totalPoints: Int? = nil,
        totalEvents: Int? = nil,
        todayEventCount: Int? = nil,
        lastEventDate: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        recentEvents: [ExperiencePointsEvent]? = nil
    ) {
        self.experienceKey = experienceKey
        self.userId = userId
        self.totalPoints = totalPoints
        self.totalEvents = totalEvents
        self.todayEventCount = todayEventCount
        self.lastEventDate = lastEventDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recentEvents = recentEvents
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case experienceKey = "experience_id"
        case userId = "user_id"
        case totalPoints = "total_points"
        case totalEvents = "total_events"
        case todayEventCount = "today_event_count"
        case lastEventDate = "last_event_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case recentEvents = "recent_events"
    }

    // MARK: - Calendar Day Helpers

    /// Get calendar days with events from recent events
    /// - Parameter timezone: Timezone for day calculations (default: current)
    /// - Returns: Array of dates (start of day) where events occurred
    public func getCalendarDaysWithEvents(
        timezone: TimeZone = .current
    ) -> [Date] {
        guard let recentEvents = recentEvents, !recentEvents.isEmpty else {
            return []
        }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        // Group events by calendar day
        let eventDays = Dictionary(grouping: recentEvents) { event -> Date in
            calendar.startOfDay(for: event.timestamp)
        }.keys.sorted()

        return Array(eventDays)
    }

    /// Get calendar days with events for the current week (Sunday to Saturday)
    /// - Parameter timezone: Timezone for day calculations (default: current)
    /// - Returns: Array of dates (start of day) where events occurred this week
    public func getCalendarDaysWithEventsThisWeek(
        timezone: TimeZone = .current
    ) -> [Date] {
        var calendar = Calendar.current
        calendar.timeZone = timezone
        calendar.firstWeekday = 1 // Sunday

        let now = Date()

        // Get the start of the current week (Sunday)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }

        let allDays = getCalendarDaysWithEvents(timezone: timezone)

        // Filter to only days within this week
        return allDays.filter { day in
            day >= weekInterval.start && day <= now
        }
    }

    /// Get total points earned today
    /// - Parameter timezone: Timezone for day calculation (default: current)
    /// - Returns: Total points earned today
    public func getTodayTotalPoints(
        timezone: TimeZone = .current
    ) -> Int {
        guard let recentEvents = recentEvents else { return 0 }

        var calendar = Calendar.current
        calendar.timeZone = timezone
        let todayStart = calendar.startOfDay(for: Date())

        return recentEvents
            .filter { calendar.isDate($0.timestamp, inSameDayAs: todayStart) }
            .reduce(0) { $0 + $1.points }
    }

    // MARK: - Computed Properties

    /// Indicates if the data is stale and may not reflect the current server state
    /// Data is considered stale if it hasn't been updated in 1 hour or more
    /// This typically happens when the user is offline or has connectivity issues
    public var isDataStale: Bool {
        guard let updatedAt = updatedAt else { return true }
        let hoursSinceUpdate = Date().timeIntervalSince(updatedAt) / 3600
        return hoursSinceUpdate >= 1
    }

    /// Days since last XP event
    public var daysSinceLastEvent: Int? {
        guard let lastEventDate = lastEventDate else { return nil }

        let calendar = Calendar.current
        let now = Date()

        let lastDay = calendar.startOfDay(for: lastEventDate)
        let today = calendar.startOfDay(for: now)

        let components = calendar.dateComponents([.day], from: lastDay, to: today)
        return components.day
    }

    // MARK: - Validation

    /// Validates data integrity
    public var isValid: Bool {
        // All Int values must be >= 0
        if let total = totalPoints, total < 0 { return false }
        if let events = totalEvents, events < 0 { return false }
        if let today = todayEventCount, today < 0 { return false }

        return true
    }

    // MARK: - Analytics

    /// Event parameters for analytics logging
    public var eventParameters: [String: Any] {
        var params: [String: Any] = [
            "current_xp_experience_id": experienceKey
        ]

        if let userId = userId { params["current_xp_user_id"] = userId }
        if let total = totalPoints { params["current_xp_total_points"] = total }
        if let events = totalEvents { params["current_xp_total_events"] = events }
        if let today = todayEventCount { params["current_xp_today_event_count"] = today }
        if let daysSince = daysSinceLastEvent { params["current_xp_days_since_last_event"] = daysSince }

        params["current_xp_is_data_stale"] = isDataStale

        return params
    }

    // MARK: - Mock Factory

    public static func mock(
        experienceKey: String = "main",
        userId: String? = "mock_user_123",
        totalPoints: Int = 1500,
        totalEvents: Int = 25,
        todayEventCount: Int = 3,
        lastEventDate: Date = Date(),
        createdAt: Date? = Calendar.current.date(byAdding: .month, value: -1, to: Date()),
        updatedAt: Date = Date()
    ) -> Self {
        CurrentExperiencePointsData(
            experienceKey: experienceKey,
            userId: userId,
            totalPoints: totalPoints,
            totalEvents: totalEvents,
            todayEventCount: todayEventCount,
            lastEventDate: lastEventDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Blank XP data (no events, zero points)
    public static func blank(experienceKey: String) -> Self {
        CurrentExperiencePointsData(
            experienceKey: experienceKey,
            totalPoints: 0,
            totalEvents: 0,
            todayEventCount: 0
        )
    }

    /// Mock with no events
    public static func mockEmpty(experienceKey: String = "main") -> Self {
        CurrentExperiencePointsData(
            experienceKey: experienceKey,
            totalPoints: 0,
            totalEvents: 0,
            todayEventCount: 0
        )
    }

    /// Mock with active XP earning
    public static func mockActive(
        experienceKey: String = "main",
        userId: String? = "mock_user_123",
        totalPoints: Int = 2500
    ) -> Self {
        CurrentExperiencePointsData(
            experienceKey: experienceKey,
            userId: userId,
            totalPoints: totalPoints,
            totalEvents: 50,
            todayEventCount: 5,
            lastEventDate: Date(),
            createdAt: Calendar.current.date(byAdding: .month, value: -2, to: Date()),
            updatedAt: Date()
        )
    }

    /// Mock with recent activity
    public static func mockWithRecentEvents(
        experienceKey: String = "main",
        userId: String? = "mock_user_123",
        eventCount: Int = 10
    ) -> Self {
        let events = (0..<eventCount).map { daysAgo in
            ExperiencePointsEvent.mock(daysAgo: daysAgo, experienceKey: experienceKey, points: 100 + daysAgo * 10)
        }

        let totalPoints = events.reduce(0) { $0 + $1.points }

        return CurrentExperiencePointsData(
            experienceKey: experienceKey,
            userId: userId,
            totalPoints: totalPoints,
            totalEvents: eventCount,
            todayEventCount: 1,
            lastEventDate: Date(),
            createdAt: Calendar.current.date(byAdding: .day, value: -eventCount, to: Date()),
            updatedAt: Date(),
            recentEvents: events
        )
    }
}
