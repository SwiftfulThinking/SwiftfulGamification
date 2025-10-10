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
    ///   - currentDate: Current date (for testing, defaults to Date())
    ///   - timezone: Timezone for calculations (defaults to current)
    /// - Returns: Calculated experience points data
    public static func calculateExperiencePoints(
        events: [ExperiencePointsEvent],
        configuration: ExperiencePointsConfiguration,
        currentDate: Date = Date(),
        timezone: TimeZone = .current
    ) -> CurrentExperiencePointsData {
        guard !events.isEmpty else {
            return CurrentExperiencePointsData.blank(experienceKey: configuration.experienceKey)
        }

        // CALCULATE TOTAL POINTS
        let totalPoints = events.reduce(0) { $0 + $1.points }

        // GET TODAY'S EVENT COUNT
        let todayEventCount = getTodayEventCount(
            events: events,
            timezone: timezone,
            currentDate: currentDate
        )

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
            totalPoints: totalPoints,
            totalEvents: events.count,
            todayEventCount: todayEventCount,
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
