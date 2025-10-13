//
//  ExperiencePointsCalculator.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

public struct ExperiencePointsCalculator {

    /// Calculates experience points data from a list of events
    /// - Parameters:
    ///   - events: All XP events for the user
    ///   - configuration: Experience points configuration
    ///   - userId: User identifier (optional, for persistence)
    ///   - currentDate: Current date (for testing, defaults to Date())
    ///   - timezone: Timezone for calculations (defaults to current)
    /// - Returns: Calculated experience points data
    public static func calculateExperiencePoints(
        events: [ExperiencePointsEvent],
        configuration: ExperiencePointsConfiguration,
        userId: String? = nil,
        currentDate: Date = Date(),
        timezone: TimeZone = .current
    ) -> CurrentExperiencePointsData {
        guard !events.isEmpty else {
            return CurrentExperiencePointsData.blank(experienceKey: configuration.experienceKey)
        }

        var calendar = Calendar.current
        calendar.timeZone = timezone
        let todayStart = calendar.startOfDay(for: currentDate)

        // CALCULATE POINTS TODAY
        let pointsToday = events
            .filter { calendar.isDate($0.timestamp, inSameDayAs: todayStart) }
            .reduce(0) { $0 + $1.points }

        // GET TODAY'S EVENT COUNT
        let eventsTodayCount = getTodayEventCount(
            events: events,
            timezone: timezone,
            currentDate: currentDate
        )

        // CALCULATE POINTS THIS WEEK (since Sunday)
        calendar.firstWeekday = 1 // Sunday
        let pointsThisWeek: Int
        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentDate) {
            pointsThisWeek = events
                .filter { $0.timestamp >= weekInterval.start && $0.timestamp <= currentDate }
                .reduce(0) { $0 + $1.points }
        } else {
            pointsThisWeek = 0
        }

        // CALCULATE POINTS LAST 7 DAYS (rolling)
        let pointsLast7Days: Int
        if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: currentDate) {
            pointsLast7Days = events
                .filter { $0.timestamp >= sevenDaysAgo && $0.timestamp <= currentDate }
                .reduce(0) { $0 + $1.points }
        } else {
            pointsLast7Days = 0
        }

        // CALCULATE POINTS THIS MONTH (since 1st)
        let pointsThisMonth: Int
        if let monthInterval = calendar.dateInterval(of: .month, for: currentDate) {
            pointsThisMonth = events
                .filter { $0.timestamp >= monthInterval.start && $0.timestamp <= currentDate }
                .reduce(0) { $0 + $1.points }
        } else {
            pointsThisMonth = 0
        }

        // CALCULATE POINTS LAST 30 DAYS (rolling)
        let pointsLast30Days: Int
        if let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: currentDate) {
            pointsLast30Days = events
                .filter { $0.timestamp >= thirtyDaysAgo && $0.timestamp <= currentDate }
                .reduce(0) { $0 + $1.points }
        } else {
            pointsLast30Days = 0
        }

        // CALCULATE POINTS THIS YEAR (since January 1st)
        let pointsThisYear: Int
        if let yearInterval = calendar.dateInterval(of: .year, for: currentDate) {
            pointsThisYear = events
                .filter { $0.timestamp >= yearInterval.start && $0.timestamp <= currentDate }
                .reduce(0) { $0 + $1.points }
        } else {
            pointsThisYear = 0
        }

        // CALCULATE POINTS LAST 12 MONTHS (rolling)
        let pointsLast12Months: Int
        if let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: currentDate) {
            pointsLast12Months = events
                .filter { $0.timestamp >= twelveMonthsAgo && $0.timestamp <= currentDate }
                .reduce(0) { $0 + $1.points }
        } else {
            pointsLast12Months = 0
        }

        // LAST EVENT INFO
        let lastEvent = events.max(by: { $0.timestamp < $1.timestamp })

        // GET RECENT EVENTS (last 60 days)
        let recentEvents = getRecentEvents(
            events: events,
            days: 60,
            timezone: timezone,
            currentDate: currentDate
        )

        return CurrentExperiencePointsData(
            experienceKey: configuration.experienceKey,
            userId: userId,
            pointsToday: pointsToday,
            eventsTodayCount: eventsTodayCount,
            pointsThisWeek: pointsThisWeek,
            pointsLast7Days: pointsLast7Days,
            pointsThisMonth: pointsThisMonth,
            pointsLast30Days: pointsLast30Days,
            pointsThisYear: pointsThisYear,
            pointsLast12Months: pointsLast12Months,
            lastEventDate: lastEvent?.timestamp,
            createdAt: events.first?.timestamp,
            updatedAt: currentDate,
            recentEvents: recentEvents
        )
    }

    /// Gets the count of events logged today
    /// - Parameters:
    ///   - events: All events
    ///   - timezone: Timezone for day calculation
    ///   - currentDate: Current date
    /// - Returns: Number of events today
    public static func getTodayEventCount(
        events: [ExperiencePointsEvent],
        timezone: TimeZone,
        currentDate: Date
    ) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let todayStart = calendar.startOfDay(for: currentDate)

        return events.filter { event in
            calendar.isDate(event.timestamp, inSameDayAs: todayStart)
        }.count
    }

    /// Gets recent events from the last X calendar days
    /// - Parameters:
    ///   - events: All events
    ///   - days: Number of calendar days to look back
    ///   - timezone: Timezone for day calculation
    ///   - currentDate: Current date
    /// - Returns: Events from the last X calendar days, sorted by timestamp
    public static func getRecentEvents(
        events: [ExperiencePointsEvent],
        days: Int,
        timezone: TimeZone,
        currentDate: Date
    ) -> [ExperiencePointsEvent] {
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let todayStart = calendar.startOfDay(for: currentDate)

        // Calculate cutoff date: go back {days} calendar days
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: todayStart) else {
            return []
        }

        // Filter events that fall within our date range
        let recentEvents = events.filter { $0.timestamp >= cutoffDate }

        // Group by calendar day and only include the last {days} unique days
        let eventsByDay = Dictionary(grouping: recentEvents) { event -> Date in
            calendar.startOfDay(for: event.timestamp)
        }

        // Get the last {days} unique calendar days
        let lastDays = Set(eventsByDay.keys.sorted().suffix(days))

        // Return events that fall on those days
        return recentEvents
            .filter { event in
                let eventDay = calendar.startOfDay(for: event.timestamp)
                return lastDays.contains(eventDay)
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Gets total points for events matching a specific metadata field value
    /// - Parameters:
    ///   - events: All events
    ///   - field: Metadata field key to filter by
    ///   - value: Metadata field value to match
    /// - Returns: Total points for matching events
    public static func getTotalPointsForMetadata(
        events: [ExperiencePointsEvent],
        field: String,
        value: GamificationDictionaryValue
    ) -> Int {
        events
            .filter { $0.metadata[field] == value }
            .reduce(0) { $0 + $1.points }
    }

    /// Gets all events matching a specific metadata field value
    /// - Parameters:
    ///   - events: All events
    ///   - field: Metadata field key to filter by
    ///   - value: Metadata field value to match
    /// - Returns: Events matching the metadata filter
    public static func getEventsForMetadata(
        events: [ExperiencePointsEvent],
        field: String,
        value: GamificationDictionaryValue
    ) -> [ExperiencePointsEvent] {
        events.filter { $0.metadata[field] == value }
    }
}
