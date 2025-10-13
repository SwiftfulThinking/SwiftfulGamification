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

    /// Points earned today
    public let pointsToday: Int?

    /// Number of XP events logged today
    public let eventsTodayCount: Int?

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
        pointsToday: Int? = nil,
        eventsTodayCount: Int? = nil,
        lastEventDate: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        recentEvents: [ExperiencePointsEvent]? = nil
    ) {
        self.experienceKey = experienceKey
        self.userId = userId
        self.pointsToday = pointsToday
        self.eventsTodayCount = eventsTodayCount
        self.lastEventDate = lastEventDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.recentEvents = recentEvents
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case experienceKey = "experience_id"
        case userId = "user_id"
        case pointsToday = "points_today"
        case eventsTodayCount = "events_today_count"
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

    // MARK: - Computed Properties - Time Windows

    /// Points earned this week (since Sunday)
    /// - Parameter timezone: Timezone for week calculation (default: current)
    /// - Returns: Total points earned this week
    public func pointsThisWeek(timezone: TimeZone = .current) -> Int {
        guard let recentEvents = recentEvents else { return 0 }

        var calendar = Calendar.current
        calendar.timeZone = timezone
        calendar.firstWeekday = 1 // Sunday

        let now = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }

        return recentEvents
            .filter { $0.timestamp >= weekInterval.start && $0.timestamp <= now }
            .reduce(0) { $0 + $1.points }
    }

    /// Points earned in the last 7 days (rolling window)
    /// - Parameter timezone: Timezone for day calculation (default: current)
    /// - Returns: Total points earned in last 7 days
    public func pointsLast7Days(timezone: TimeZone = .current) -> Int {
        guard let recentEvents = recentEvents else { return 0 }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()
        guard let cutoffDate = calendar.date(byAdding: .day, value: -7, to: now) else {
            return 0
        }

        return recentEvents
            .filter { $0.timestamp >= cutoffDate && $0.timestamp <= now }
            .reduce(0) { $0 + $1.points }
    }

    /// Points earned this month (since 1st of month)
    /// - Parameter timezone: Timezone for month calculation (default: current)
    /// - Returns: Total points earned this month
    public func pointsThisMonth(timezone: TimeZone = .current) -> Int {
        guard let recentEvents = recentEvents else { return 0 }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            return 0
        }

        return recentEvents
            .filter { $0.timestamp >= monthInterval.start && $0.timestamp <= now }
            .reduce(0) { $0 + $1.points }
    }

    /// Points earned in the last 30 days (rolling window)
    /// - Parameter timezone: Timezone for day calculation (default: current)
    /// - Returns: Total points earned in last 30 days
    public func pointsLast30Days(timezone: TimeZone = .current) -> Int {
        guard let recentEvents = recentEvents else { return 0 }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()
        guard let cutoffDate = calendar.date(byAdding: .day, value: -30, to: now) else {
            return 0
        }

        return recentEvents
            .filter { $0.timestamp >= cutoffDate && $0.timestamp <= now }
            .reduce(0) { $0 + $1.points }
    }

    /// Points earned this year (since January 1st)
    /// - Parameter timezone: Timezone for year calculation (default: current)
    /// - Returns: Total points earned this year
    public func pointsThisYear(timezone: TimeZone = .current) -> Int {
        guard let recentEvents = recentEvents else { return 0 }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()
        guard let yearInterval = calendar.dateInterval(of: .year, for: now) else {
            return 0
        }

        return recentEvents
            .filter { $0.timestamp >= yearInterval.start && $0.timestamp <= now }
            .reduce(0) { $0 + $1.points }
    }

    /// Points earned in the last 12 months (rolling window)
    /// - Parameter timezone: Timezone for month calculation (default: current)
    /// - Returns: Total points earned in last 12 months
    public func pointsLast12Months(timezone: TimeZone = .current) -> Int {
        guard let recentEvents = recentEvents else { return 0 }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()
        guard let cutoffDate = calendar.date(byAdding: .month, value: -12, to: now) else {
            return 0
        }

        return recentEvents
            .filter { $0.timestamp >= cutoffDate && $0.timestamp <= now }
            .reduce(0) { $0 + $1.points }
    }

    // MARK: - Computed Properties - Other

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
        if let points = pointsToday, points < 0 { return false }
        if let events = eventsTodayCount, events < 0 { return false }

        return true
    }

    // MARK: - Helpers

    /// Returns a copy of this data with an updated userId
    public func updatingUserId(_ userId: String) -> CurrentExperiencePointsData {
        CurrentExperiencePointsData(
            experienceKey: experienceKey,
            userId: userId,
            pointsToday: pointsToday,
            eventsTodayCount: eventsTodayCount,
            lastEventDate: lastEventDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recentEvents: recentEvents
        )
    }

    // MARK: - Analytics

    /// Event parameters for analytics logging
    public var eventParameters: [String: Any] {
        var params: [String: Any] = [
            "current_xp_experience_id": experienceKey
        ]

        if let userId = userId { params["current_xp_user_id"] = userId }
        if let points = pointsToday { params["current_xp_points_today"] = points }
        if let events = eventsTodayCount { params["current_xp_events_today_count"] = events }
        if let daysSince = daysSinceLastEvent { params["current_xp_days_since_last_event"] = daysSince }

        params["current_xp_is_data_stale"] = isDataStale

        return params
    }

    // MARK: - Mock Factory

    public static func mock(
        experienceKey: String = "main",
        userId: String? = "mock_user_123",
        pointsToday: Int = 150,
        eventsTodayCount: Int = 3,
        lastEventDate: Date = Date(),
        createdAt: Date? = Calendar.current.date(byAdding: .month, value: -1, to: Date()),
        updatedAt: Date = Date()
    ) -> Self {
        CurrentExperiencePointsData(
            experienceKey: experienceKey,
            userId: userId,
            pointsToday: pointsToday,
            eventsTodayCount: eventsTodayCount,
            lastEventDate: lastEventDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Blank XP data (no events, zero points)
    public static func blank(experienceKey: String) -> Self {
        CurrentExperiencePointsData(
            experienceKey: experienceKey,
            pointsToday: 0,
            eventsTodayCount: 0
        )
    }

    /// Mock with no events
    public static func mockEmpty(experienceKey: String = "main") -> Self {
        CurrentExperiencePointsData(
            experienceKey: experienceKey,
            pointsToday: 0,
            eventsTodayCount: 0
        )
    }

    /// Mock with active XP earning
    public static func mockActive(
        experienceKey: String = "main",
        userId: String? = "mock_user_123",
        pointsToday: Int = 250
    ) -> Self {
        // Generate mock events spread over last 30 days
        let eventCount = 50
        let pointsPerEvent = 50
        let events = (0..<eventCount).map { daysAgo in
            ExperiencePointsEvent.mock(
                daysAgo: daysAgo % 30, // Spread over last 30 days
                experienceKey: experienceKey,
                points: pointsPerEvent
            )
        }

        // Calculate fields from events (matching ExperiencePointsCalculator logic)
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)

        let eventsTodayCount = events.filter { event in
            calendar.isDate(event.timestamp, inSameDayAs: todayStart)
        }.count

        let todayPoints = events
            .filter { calendar.isDate($0.timestamp, inSameDayAs: todayStart) }
            .reduce(0) { $0 + $1.points }

        let lastEvent = events.max(by: { $0.timestamp < $1.timestamp })
        let firstEvent = events.min(by: { $0.timestamp < $1.timestamp })

        return CurrentExperiencePointsData(
            experienceKey: experienceKey,
            userId: userId,
            pointsToday: todayPoints,
            eventsTodayCount: eventsTodayCount,
            lastEventDate: lastEvent?.timestamp,
            createdAt: firstEvent?.timestamp,
            updatedAt: today,
            recentEvents: events
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

        // Calculate fields from events (matching ExperiencePointsCalculator logic)
        let calendar = Calendar.current
        let today = Date()
        let todayStart = calendar.startOfDay(for: today)

        let pointsToday = events
            .filter { calendar.isDate($0.timestamp, inSameDayAs: todayStart) }
            .reduce(0) { $0 + $1.points }

        let eventsTodayCount = events.filter { event in
            calendar.isDate(event.timestamp, inSameDayAs: todayStart)
        }.count

        let lastEvent = events.max(by: { $0.timestamp < $1.timestamp })
        let firstEvent = events.min(by: { $0.timestamp < $1.timestamp })

        return CurrentExperiencePointsData(
            experienceKey: experienceKey,
            userId: userId,
            pointsToday: pointsToday,
            eventsTodayCount: eventsTodayCount,
            lastEventDate: lastEvent?.timestamp,
            createdAt: firstEvent?.timestamp,
            updatedAt: today,
            recentEvents: events
        )
    }
}
