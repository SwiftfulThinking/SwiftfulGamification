//
//  CurrentStreakData.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

/// Represents a user's current streak status
public struct CurrentStreakData: Identifiable, Codable, Sendable, Equatable {
    /// Identifiable conformance - uses streakKey
    public var id: String {
        streakKey
    }

    /// Streak identifier (e.g., "workout", "reading")
    public let streakKey: String

    /// User identifier
    public let userId: String?

    /// Current consecutive streak count
    public let currentStreak: Int?

    /// All-time longest streak achieved
    public let longestStreak: Int?

    /// UTC timestamp of last event
    public let dateLastEvent: Date?

    /// Timezone identifier of last event
    public let lastEventTimezone: String?

    /// UTC timestamp when current streak started
    public let dateStreakStart: Date?

    /// Total number of events logged
    public let totalEvents: Int?

    /// Available streak freezes
    public let freezesAvailable: [StreakFreeze]?

    /// Number of streak freezes available
    public let freezesAvailableCount: Int?

    /// UTC timestamp of first event ever
    public let dateCreated: Date?

    /// UTC timestamp of last update
    public let dateUpdated: Date?

    /// Goal-based: number of events required per day (1 = basic streak)
    public let eventsRequiredPerDay: Int?

    /// Goal-based: number of events logged today
    public let todayEventCount: Int?

    /// Recent events for calendar display (last 60 days)
    public let recentEvents: [StreakEvent]?

    // MARK: - Initialization

    public init(
        streakKey: String,
        userId: String? = nil,
        currentStreak: Int? = nil,
        longestStreak: Int? = nil,
        dateLastEvent: Date? = nil,
        lastEventTimezone: String? = nil,
        dateStreakStart: Date? = nil,
        totalEvents: Int? = nil,
        freezesAvailable: [StreakFreeze]? = nil,
        freezesAvailableCount: Int? = nil,
        dateCreated: Date? = nil,
        dateUpdated: Date? = nil,
        eventsRequiredPerDay: Int? = nil,
        todayEventCount: Int? = nil,
        recentEvents: [StreakEvent]? = nil
    ) {
        self.streakKey = streakKey
        self.userId = userId
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.dateLastEvent = dateLastEvent
        self.lastEventTimezone = lastEventTimezone
        self.dateStreakStart = dateStreakStart
        self.totalEvents = totalEvents
        self.freezesAvailable = freezesAvailable
        self.freezesAvailableCount = freezesAvailableCount
        self.dateCreated = dateCreated
        self.dateUpdated = dateUpdated
        self.eventsRequiredPerDay = eventsRequiredPerDay
        self.todayEventCount = todayEventCount
        self.recentEvents = recentEvents
    }

    // MARK: - Codable

    public enum CodingKeys: String, CodingKey {
        case streakKey = "streak_id"
        case userId = "user_id"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case dateLastEvent = "date_last_event"
        case lastEventTimezone = "last_event_timezone"
        case dateStreakStart = "date_streak_start"
        case totalEvents = "total_events"
        case freezesAvailable = "freezes_available"
        case freezesAvailableCount = "freezes_available_count"
        case dateCreated = "date_created"
        case dateUpdated = "date_updated"
        case eventsRequiredPerDay = "events_required_per_day"
        case todayEventCount = "today_event_count"
        case recentEvents = "recent_events"
    }

    // MARK: - Calendar Day Helpers

    /// Get calendar days with events from recent events
    /// - Parameters:
    ///   - timezone: Timezone for day calculations (default: current)
    ///   - leewayHours: Leeway hours to apply (default: 0)
    /// - Returns: Array of dates (start of day) where events occurred
    public func getCalendarDaysWithEvents(
        timezone: TimeZone = .current,
        leewayHours: Int = 0
    ) -> [Date] {
        guard let recentEvents = recentEvents, !recentEvents.isEmpty else {
            return []
        }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        // Group events by calendar day, accounting for leeway
        let eventDays = Dictionary(grouping: recentEvents) { event -> Date in
            let eventDay = calendar.startOfDay(for: event.dateCreated)

            // If leeway, adjust the day boundary
            if leewayHours > 0 {
                let hoursSinceMidnight = calendar.dateComponents([.hour], from: eventDay, to: event.dateCreated).hour ?? 0

                // If event is within leeway hours after midnight, count it as previous day
                if hoursSinceMidnight <= leewayHours {
                    return calendar.date(byAdding: .day, value: -1, to: eventDay) ?? eventDay
                }
            }

            return eventDay
        }.keys.sorted()

        return Array(eventDays)
    }

    /// Get calendar days with events for the current week (Sunday to Saturday)
    /// - Parameters:
    ///   - timezone: Timezone for day calculations (default: current)
    ///   - leewayHours: Leeway hours to apply (default: 0)
    /// - Returns: Array of dates (start of day) where events occurred this week
    public func getCalendarDaysWithEventsThisWeek(
        timezone: TimeZone = .current,
        leewayHours: Int = 0
    ) -> [Date] {
        var calendar = Calendar.current
        calendar.timeZone = timezone
        calendar.firstWeekday = 1 // Sunday

        let now = Date()

        // Get the start of the current week (Sunday)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }

        let allDays = getCalendarDaysWithEvents(timezone: timezone, leewayHours: leewayHours)

        // Filter to only days within this week
        return allDays.filter { day in
            day >= weekInterval.start && day <= now
        }
    }

    // MARK: - Computed Properties

    /// Current status of the streak
    public var status: StreakStatus {
        guard dateLastEvent != nil else {
            return .noEvents
        }

        guard let daysSince = daysSinceLastEvent else {
            return .noEvents
        }

        // Check if we're within leeway window
        // Note: This is a simplified check - full leeway logic requires configuration
        if daysSince == 0 {
            return .active(daysSinceLastEvent: 0)
        } else if daysSince == 1 {
            return .atRisk
        } else if daysSince >= 2 {
            return .broken(daysSinceLastEvent: daysSince)
        }

        return .active(daysSinceLastEvent: daysSince)
    }

    /// Is the streak currently active (last event was today or yesterday)?
    public var isStreakActive: Bool {
        guard dateLastEvent != nil else { return false }
        guard let daysSince = daysSinceLastEvent else { return false }
        return daysSince <= 1
    }

    /// Is the streak at risk (last event was yesterday)?
    public var isStreakAtRisk: Bool {
        guard let daysSince = daysSinceLastEvent else { return false }
        return daysSince == 1
    }

    /// Indicates if the streak data is stale and may not reflect the current server state
    /// Data is considered stale if it hasn't been updated in 1 hour or more
    /// This typically happens when the user is offline or has connectivity issues
    public var isDataStale: Bool {
        guard let dateUpdated = dateUpdated else { return true }
        let hoursSinceUpdate = Date().timeIntervalSince(dateUpdated) / 3600
        return hoursSinceUpdate >= 1
    }

    /// Number of days since last event (in user's current timezone)
    public var daysSinceLastEvent: Int? {
        guard let dateLastEvent = dateLastEvent else { return nil }

        let calendar = Calendar.current
        let now = Date()

        let lastDay = calendar.startOfDay(for: dateLastEvent)
        let today = calendar.startOfDay(for: now)

        let components = calendar.dateComponents([.day], from: lastDay, to: today)
        return components.day
    }

    /// Number of freezes needed to save the current streak
    /// Returns nil if streak is not broken or cannot be calculated
    /// Returns 0 if streak is active (no freezes needed)
    /// Returns the gap size if streak can potentially be saved with freezes
    public var freezesNeededToSaveStreak: Int? {
        guard let daysSince = daysSinceLastEvent else { return nil }

        // If last event was today or yesterday, streak is not broken
        if daysSince <= 1 {
            return 0
        }

        // Gap size is daysSince - 1 (e.g., last event 3 days ago = 2 day gap)
        return daysSince - 1
    }

    /// Can the streak be saved with available freezes?
    /// - Returns true if the streak is active (no freeze needed) OR if enough freezes are available to fill the gap
    /// - Returns false if streak is broken and insufficient freezes available
    public var canStreakBeSaved: Bool {
        guard let freezesNeeded = freezesNeededToSaveStreak else { return false }

        // No freezes needed (streak is active)
        if freezesNeeded == 0 {
            return true
        }

        // Check if we have enough freezes to fill the gap
        let available = freezesAvailableCount ?? 0
        return available >= freezesNeeded
    }

    /// Status for applying manual streak freezes
    /// - Returns `.canSaveStreakWithFreezes(count:)` if user can save streak by using the specified number of freezes (and has enough available)
    /// - Returns `.cannotSaveStreakWithFreezes` if streak is active or not enough freezes available
    public var applyManualStreakFreezeStatus: ApplyManualStreakFreezeStatus {
        guard let freezesNeeded = freezesNeededToSaveStreak else {
            return .cannotSaveStreakWithFreezes
        }

        // If no freezes needed (streak is active), cannot apply manual freezes
        if freezesNeeded == 0 {
            return .cannotSaveStreakWithFreezes
        }

        // Check if we have enough freezes to fill the gap
        let available = freezesAvailableCount ?? 0
        if available >= freezesNeeded {
            return .canSaveStreakWithFreezes(count: freezesNeeded)
        }

        return .cannotSaveStreakWithFreezes
    }

    /// Should the user be prompted to use a freeze?
    /// Returns true when:
    /// - Streak is broken (daysSince >= 2)
    /// - At least one freeze is available
    /// - Enough freezes exist to save the streak
    public var shouldPromptFreezeUsage: Bool {
        guard let daysSince = daysSinceLastEvent else { return false }
        guard let freezesNeeded = freezesNeededToSaveStreak else { return false }

        // Only prompt if streak is actually broken
        if daysSince < 2 {
            return false
        }

        // Only prompt if we can actually save it
        return canStreakBeSaved && freezesNeeded > 0
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

    // MARK: - Helpers

    /// Returns a copy of this data with an updated userId
    public func updatingUserId(_ userId: String) -> CurrentStreakData {
        CurrentStreakData(
            streakKey: streakKey,
            userId: userId,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            dateLastEvent: dateLastEvent,
            lastEventTimezone: lastEventTimezone,
            dateStreakStart: dateStreakStart,
            totalEvents: totalEvents,
            freezesAvailable: freezesAvailable,
            freezesAvailableCount: freezesAvailableCount,
            dateCreated: dateCreated,
            dateUpdated: dateUpdated,
            eventsRequiredPerDay: eventsRequiredPerDay,
            todayEventCount: todayEventCount,
            recentEvents: recentEvents
        )
    }

    // MARK: - Validation

    /// Validates data integrity
    public var isValid: Bool {
        // All Int values must be >= 0
        if let current = currentStreak, current < 0 { return false }
        if let longest = longestStreak, longest < 0 { return false }
        if let total = totalEvents, total < 0 { return false }
        if let freezes = freezesAvailableCount, freezes < 0 { return false }
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
            "current_streak_streak_id": streakKey
        ]

        if let userId = userId { params["current_streak_user_id"] = userId }
        if let current = currentStreak { params["current_streak_current_streak"] = current }
        if let longest = longestStreak { params["current_streak_longest_streak"] = longest }
        if let total = totalEvents { params["current_streak_total_events"] = total }
        if let freezes = freezesAvailableCount { params["current_streak_freezes_available_count"] = freezes }
        if let required = eventsRequiredPerDay { params["current_streak_events_required_per_day"] = required }
        if let today = todayEventCount { params["current_streak_today_event_count"] = today }

        params["current_streak_is_streak_active"] = isStreakActive
        params["current_streak_is_goal_met"] = isGoalMet
        params["current_streak_goal_progress"] = goalProgress

        return params
    }

    // MARK: - Mock Factory

    public static func mock(
        streakKey: String = "workout",
        userId: String? = "mock_user_123",
        currentStreak: Int = 5,
        longestStreak: Int = 10,
        dateLastEvent: Date = Date(),
        lastEventTimezone: String = TimeZone.current.identifier,
        dateStreakStart: Date? = Calendar.current.date(byAdding: .day, value: -5, to: Date()),
        totalEvents: Int = 25,
        freezesAvailable: [StreakFreeze]? = nil,
        freezesAvailableCount: Int = 2,
        dateCreated: Date? = Calendar.current.date(byAdding: .month, value: -1, to: Date()),
        dateUpdated: Date = Date(),
        eventsRequiredPerDay: Int = 1,
        todayEventCount: Int = 1,
        recentEvents: [StreakEvent]? = nil
    ) -> Self {
        CurrentStreakData(
            streakKey: streakKey,
            userId: userId,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            dateLastEvent: dateLastEvent,
            lastEventTimezone: lastEventTimezone,
            dateStreakStart: dateStreakStart,
            totalEvents: totalEvents,
            freezesAvailable: freezesAvailable,
            freezesAvailableCount: freezesAvailableCount,
            dateCreated: dateCreated,
            dateUpdated: dateUpdated,
            eventsRequiredPerDay: eventsRequiredPerDay,
            todayEventCount: todayEventCount,
            recentEvents: recentEvents
        )
    }

    /// Blank streak data (no events, zero streak)
    public static func blank(
        streakKey: String,
        userId: String? = nil,
        freezesAvailable: [StreakFreeze]? = nil,
        freezesAvailableCount: Int? = nil,
        dateUpdated: Date? = nil,
        eventsRequiredPerDay: Int? = nil
    ) -> Self {
        CurrentStreakData(
            streakKey: streakKey,
            userId: userId,
            currentStreak: 0,
            longestStreak: 0,
            totalEvents: 0,
            freezesAvailable: freezesAvailable,
            freezesAvailableCount: freezesAvailableCount ?? 0,
            dateUpdated: dateUpdated,
            eventsRequiredPerDay: eventsRequiredPerDay ?? 1,
            todayEventCount: 0
        )
    }

    /// Mock with no events
    public static func mockEmpty(streakKey: String = "workout") -> Self {
        CurrentStreakData(
            streakKey: streakKey,
            currentStreak: 0,
            longestStreak: 0,
            totalEvents: 0,
            freezesAvailableCount: 0,
            eventsRequiredPerDay: 1,
            todayEventCount: 0
        )
    }

    /// Mock with active streak
    public static func mockActive(
        streakKey: String = "workout",
        userId: String? = "mock_user_123",
        currentStreak: Int = 7,
        freezesAvailableCount: Int = 2
    ) -> Self {
        // Generate recent events for the previous N days (NOT including today)
        // This represents a streak where the last event was yesterday
        var calendar = Calendar.current
        calendar.timeZone = .current

        let recentEvents = (1...currentStreak).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            return StreakEvent.mock(dateCreated: date)
        }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        return CurrentStreakData(
            streakKey: streakKey,
            userId: userId,
            currentStreak: currentStreak,
            longestStreak: currentStreak,
            dateLastEvent: yesterday,
            lastEventTimezone: TimeZone.current.identifier,
            dateStreakStart: Calendar.current.date(byAdding: .day, value: -currentStreak, to: yesterday),
            totalEvents: currentStreak + 5,
            freezesAvailableCount: freezesAvailableCount,
            dateCreated: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            dateUpdated: yesterday,
            eventsRequiredPerDay: 1,
            todayEventCount: 0,
            recentEvents: recentEvents
        )
    }

    /// Mock with streak at risk (yesterday was last event)
    public static func mockAtRisk(
        streakKey: String = "workout",
        userId: String? = "mock_user_123",
        currentStreak: Int = 5
    ) -> Self {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        // Generate recent events to match the current streak (ending yesterday)
        var calendar = Calendar.current
        calendar.timeZone = .current

        let recentEvents = (1...currentStreak).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            return StreakEvent.mock(dateCreated: date)
        }

        return CurrentStreakData(
            streakKey: streakKey,
            userId: userId,
            currentStreak: currentStreak,
            longestStreak: currentStreak,
            dateLastEvent: yesterday,
            lastEventTimezone: TimeZone.current.identifier,
            dateStreakStart: Calendar.current.date(byAdding: .day, value: -currentStreak, to: yesterday),
            totalEvents: currentStreak + 3,
            freezesAvailableCount: 1,
            dateCreated: Calendar.current.date(byAdding: .month, value: -1, to: Date()),
            dateUpdated: yesterday,
            eventsRequiredPerDay: 1,
            todayEventCount: 0,
            recentEvents: recentEvents
        )
    }

    /// Mock with injected recent events (calculates streak from events)
    public static func mockWithRecentEvents(
        streakKey: String = "workout",
        userId: String? = "mock_user_123",
        recentEvents: [StreakEvent],
        eventsRequiredPerDay: Int = 1,
        freezesAvailableCount: Int = 2
    ) -> Self {
        guard !recentEvents.isEmpty else {
            return blank(streakKey: streakKey)
        }

        let configuration = StreakConfiguration(
            streakKey: streakKey,
            eventsRequiredPerDay: eventsRequiredPerDay,
            useServerCalculation: false
        )

        let (calculatedStreak, _) = StreakCalculator.calculateStreak(
            events: recentEvents,
            configuration: configuration,
            userId: userId
        )

        return CurrentStreakData(
            streakKey: streakKey,
            userId: userId,
            currentStreak: calculatedStreak.currentStreak,
            longestStreak: calculatedStreak.longestStreak,
            dateLastEvent: calculatedStreak.dateLastEvent,
            lastEventTimezone: calculatedStreak.lastEventTimezone,
            dateStreakStart: calculatedStreak.dateStreakStart,
            totalEvents: calculatedStreak.totalEvents,
            freezesAvailableCount: freezesAvailableCount,
            dateCreated: calculatedStreak.dateCreated,
            dateUpdated: calculatedStreak.dateUpdated,
            eventsRequiredPerDay: eventsRequiredPerDay,
            todayEventCount: calculatedStreak.todayEventCount,
            recentEvents: recentEvents
        )
    }

    /// Mock with goal-based streak
    public static func mockGoalBased(
        streakKey: String = "workout",
        userId: String? = "mock_user_123",
        eventsRequiredPerDay: Int = 3,
        todayEventCount: Int = 1
    ) -> Self {
        // Generate recent events for a 4-day streak with goal-based requirements
        var calendar = Calendar.current
        calendar.timeZone = .current

        var recentEvents: [StreakEvent] = []

        // Days 0-3 (yesterday and before): eventsRequiredPerDay events each
        for daysAgo in 1...4 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            for hour in 0..<eventsRequiredPerDay {
                let eventDate = date.addingTimeInterval(TimeInterval(hour * 3600))
                recentEvents.append(StreakEvent.mock(dateCreated: eventDate))
            }
        }

        // Today: todayEventCount events
        for hour in 0..<todayEventCount {
            let eventDate = Date().addingTimeInterval(TimeInterval(hour * 3600))
            recentEvents.append(StreakEvent.mock(dateCreated: eventDate))
        }

        let currentStreak = 4

        return CurrentStreakData(
            streakKey: streakKey,
            userId: userId,
            currentStreak: currentStreak,
            longestStreak: currentStreak,
            dateLastEvent: Date(),
            lastEventTimezone: TimeZone.current.identifier,
            dateStreakStart: Calendar.current.date(byAdding: .day, value: -currentStreak, to: Date()),
            totalEvents: 15,
            freezesAvailableCount: 2,
            dateCreated: Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date()),
            dateUpdated: Date(),
            eventsRequiredPerDay: eventsRequiredPerDay,
            todayEventCount: todayEventCount,
            recentEvents: recentEvents
        )
    }
}
