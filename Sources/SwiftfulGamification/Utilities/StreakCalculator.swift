//
//  StreakCalculator.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-03.
//

import Foundation

public struct StreakCalculator {

    /// Calculates streak data from a list of events
    /// - Parameters:
    ///   - events: All events for the user
    ///   - configuration: Streak configuration
    ///   - currentDate: Current date (for testing, defaults to Date())
    ///   - timezone: Timezone for calculations (defaults to current)
    /// - Returns: Calculated CurrentStreakData
    public static func calculateStreak(
        events: [StreakEvent],
        configuration: StreakConfiguration,
        currentDate: Date = Date(),
        timezone: TimeZone = .current
    ) -> CurrentStreakData {
        guard !events.isEmpty else {
            return CurrentStreakData.blank(streakId: configuration.streakId)
        }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        // GROUP EVENTS BY DAY
        let eventsByDay = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.timestamp)
        }

        // GOAL-BASED MODE: Filter days that met the goal
        let qualifyingDays: [Date]
        if configuration.eventsRequiredPerDay > 1 {
            qualifyingDays = eventsByDay.filter { _, events in
                events.count >= configuration.eventsRequiredPerDay
            }.keys.sorted()
        } else {
            // BASIC MODE: Any day with at least 1 event qualifies
            qualifyingDays = eventsByDay.keys.sorted()
        }

        // CALCULATE CURRENT STREAK (walk backwards from today)
        var currentStreak = 0
        var expectedDate = calendar.startOfDay(for: currentDate)

        // Apply leeway: Extend "today" window
        if configuration.leewayHours > 0 {
            let components = calendar.dateComponents([.hour], from: expectedDate, to: currentDate)
            let hoursSinceMidnight = components.hour ?? 0

            if hoursSinceMidnight <= configuration.leewayHours {
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            }
        }

        for eventDay in qualifyingDays.reversed() {
            if calendar.isDate(eventDay, inSameDayAs: expectedDate) {
                currentStreak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            } else if eventDay < expectedDate {
                break  // Gap found
            }
        }

        // CALCULATE LONGEST STREAK
        var longestStreak = 0
        var tempStreak = 0
        var previousDay: Date?

        for eventDay in qualifyingDays {
            if let prev = previousDay {
                let dayDiff = calendar.dateComponents([.day], from: prev, to: eventDay).day ?? 0
                if dayDiff == 1 {
                    tempStreak += 1
                } else {
                    longestStreak = max(longestStreak, tempStreak)
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }
            previousDay = eventDay
        }
        longestStreak = max(longestStreak, tempStreak)
        longestStreak = max(longestStreak, currentStreak)

        // GET TODAY'S EVENT COUNT (for goal progress)
        let todayEventCount = getTodayEventCount(
            events: events,
            timezone: timezone,
            currentDate: currentDate
        )

        // LAST EVENT INFO
        let lastEvent = events.max(by: { $0.timestamp < $1.timestamp })

        // STREAK START DATE
        let streakStartDate: Date?
        if qualifyingDays.count >= currentStreak && currentStreak > 0 {
            streakStartDate = qualifyingDays[qualifyingDays.count - currentStreak]
        } else {
            streakStartDate = nil
        }

        return CurrentStreakData(
            streakId: configuration.streakId,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastEventDate: lastEvent?.timestamp,
            lastEventTimezone: lastEvent?.timezone,
            streakStartDate: streakStartDate,
            totalEvents: events.count,
            freezesRemaining: nil,
            createdAt: events.first?.timestamp,
            updatedAt: currentDate,
            eventsRequiredPerDay: configuration.eventsRequiredPerDay,
            todayEventCount: todayEventCount
        )
    }

    /// Gets the count of events logged today
    /// - Parameters:
    ///   - events: All events
    ///   - timezone: Timezone for day calculation
    ///   - currentDate: Current date
    /// - Returns: Number of events today
    public static func getTodayEventCount(
        events: [StreakEvent],
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
}
