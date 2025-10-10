//
//  StreakCalculator.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-03.
//

import Foundation

public struct StreakCalculator {

    public typealias FreezeConsumption = (freezeId: String, date: Date)

    /// Calculates streak data from a list of events
    /// - Parameters:
    ///   - events: All events for the user
    ///   - freezes: Available freezes for auto-consumption
    ///   - configuration: Streak configuration
    ///   - userId: User ID to store in the streak data
    ///   - currentDate: Current date (for testing, defaults to Date())
    ///   - timezone: Timezone for calculations (defaults to current)
    /// - Returns: Tuple of (calculated streak, array of freeze consumptions with dates)
    public static func calculateStreak(
        events: [StreakEvent],
        freezes: [StreakFreeze] = [],
        configuration: StreakConfiguration,
        userId: String? = nil,
        currentDate: Date = Date(),
        timezone: TimeZone = .current
    ) -> (streak: CurrentStreakData, freezeConsumptions: [FreezeConsumption]) {
        guard !events.isEmpty else {
            let blankStreak = CurrentStreakData.blank(streakKey: configuration.streakKey)
            let streakWithUser = CurrentStreakData(
                streakKey: blankStreak.streakKey,
                userId: userId,
                currentStreak: blankStreak.currentStreak,
                longestStreak: blankStreak.longestStreak,
                lastEventDate: blankStreak.lastEventDate,
                lastEventTimezone: blankStreak.lastEventTimezone,
                streakStartDate: blankStreak.streakStartDate,
                totalEvents: blankStreak.totalEvents,
                freezesRemaining: freezes.filter { $0.isAvailable }.count,
                createdAt: blankStreak.createdAt,
                updatedAt: currentDate,
                eventsRequiredPerDay: configuration.eventsRequiredPerDay,
                todayEventCount: blankStreak.todayEventCount,
                recentEvents: blankStreak.recentEvents
            )
            return (streakWithUser, [])
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

        // CALCULATE CURRENT STREAK (walk backwards from today) with freeze support
        var currentStreak = 0
        var expectedDate = calendar.startOfDay(for: currentDate)
        var freezeConsumptions: [FreezeConsumption] = []
        var availableFreezes = freezes.filter { $0.isAvailable }.sorted { ($0.earnedDate ?? Date.distantPast) < ($1.earnedDate ?? Date.distantPast) }

        // Apply leeway: Extend "today" window
        if configuration.leewayHours > 0 {
            let components = calendar.dateComponents([.hour], from: expectedDate, to: currentDate)
            let hoursSinceMidnight = components.hour ?? 0

            if hoursSinceMidnight <= configuration.leewayHours {
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
            }
        }

        // Track if we've started counting (to handle "today has no event" edge case)
        var hasStartedStreak = false

        for eventDay in qualifyingDays.reversed() {
            if calendar.isDate(eventDay, inSameDayAs: expectedDate) {
                currentStreak += 1
                expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
                hasStartedStreak = true
            } else if eventDay < expectedDate {
                // Gap found - calculate gap size
                let daysBetween = calendar.dateComponents([.day], from: eventDay, to: expectedDate).day ?? 0

                // EDGE CASE FIX: If we haven't started counting yet (no event today) and gap is only 1 day,
                // this is the "at risk" state - yesterday's event should still count
                // BUT: Only if we're checking on the same day as expectedDate (meaning we're still "today")
                // OR if leeway is enabled (grace period applies)
                let checkingOnExpectedDay = calendar.isDate(currentDate, inSameDayAs: expectedDate)
                let leewayApplied = configuration.leewayHours > 0

                if !hasStartedStreak && daysBetween == 1 && (checkingOnExpectedDay || leewayApplied) {
                    currentStreak += 1
                    expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
                    hasStartedStreak = true
                    continue
                }

                // Try to fill the gap with freezes if autoConsumeFreeze is enabled
                if configuration.autoConsumeFreeze {
                    var gapFilled = false

                    // Check if we can fill the gap with a freeze
                    while eventDay < expectedDate && !availableFreezes.isEmpty {
                        let freeze = availableFreezes.removeFirst()
                        freezeConsumptions.append((freezeId: freeze.id, date: expectedDate))
                        currentStreak += 1
                        expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
                        gapFilled = true
                        hasStartedStreak = true

                        // Check if we've now reached the event day
                        if calendar.isDate(eventDay, inSameDayAs: expectedDate) {
                            currentStreak += 1
                            expectedDate = calendar.date(byAdding: .day, value: -1, to: expectedDate) ?? expectedDate
                            break
                        }
                    }

                    // If we couldn't fill the entire gap, streak is broken
                    if !calendar.isDate(eventDay, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: expectedDate) ?? expectedDate) && !gapFilled {
                        break
                    }
                } else {
                    break  // Gap found, no freeze auto-consume
                }
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
        if currentStreak > 0 {
            // Calculate start date by walking back from today, accounting for both events and freezes
            var startDate = calendar.startOfDay(for: currentDate)

            // Apply leeway offset if applicable
            if configuration.leewayHours > 0 {
                let components = calendar.dateComponents([.hour], from: startDate, to: currentDate)
                let hoursSinceMidnight = components.hour ?? 0

                if hoursSinceMidnight <= configuration.leewayHours {
                    startDate = calendar.date(byAdding: .day, value: -1, to: startDate) ?? startDate
                }
            }

            // Walk back (currentStreak - 1) days to find the start
            if currentStreak > 1 {
                startDate = calendar.date(byAdding: .day, value: -(currentStreak - 1), to: startDate) ?? startDate
            }

            streakStartDate = startDate
        } else {
            streakStartDate = nil
        }

        // COUNT REMAINING FREEZES
        let freezesRemaining = availableFreezes.count

        // GET RECENT EVENTS (last 60 days, accounting for leeway)
        let recentEvents = getRecentEvents(
            events: events,
            days: 60,
            timezone: timezone,
            leewayHours: configuration.leewayHours,
            currentDate: currentDate
        )

        let streak = CurrentStreakData(
            streakKey: configuration.streakKey,
            userId: userId,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastEventDate: lastEvent?.timestamp,
            lastEventTimezone: lastEvent?.timezone,
            streakStartDate: streakStartDate,
            totalEvents: events.count,
            freezesRemaining: freezesRemaining,
            createdAt: events.first?.timestamp,
            updatedAt: currentDate,
            eventsRequiredPerDay: configuration.eventsRequiredPerDay,
            todayEventCount: todayEventCount,
            recentEvents: recentEvents
        )

        return (streak, freezeConsumptions)
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

    /// Gets recent events from the last X calendar days (accounting for leeway)
    /// - Parameters:
    ///   - events: All events
    ///   - days: Number of calendar days to look back
    ///   - timezone: Timezone for day calculation
    ///   - leewayHours: Leeway hours for day boundary adjustment
    ///   - currentDate: Current date
    /// - Returns: Events from the last X calendar days, sorted by timestamp
    ///
    /// This function ensures we get events for X complete calendar days, accounting for leeway.
    /// For example, with 3 hours leeway and 10 days:
    /// - An event at 1 AM on Day 11 counts as Day 10
    /// - We look back 10 days + leeway hours to ensure we capture all events
    private static func getRecentEvents(
        events: [StreakEvent],
        days: Int,
        timezone: TimeZone,
        leewayHours: Int,
        currentDate: Date
    ) -> [StreakEvent] {
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let todayStart = calendar.startOfDay(for: currentDate)

        // Calculate cutoff date: go back {days} calendar days
        guard var cutoffDate = calendar.date(byAdding: .day, value: -days, to: todayStart) else {
            return []
        }

        // Subtract leeway hours from cutoff to ensure we capture events that fall
        // within the leeway window at the start of the cutoff day
        if leewayHours > 0 {
            cutoffDate = calendar.date(byAdding: .hour, value: -leewayHours, to: cutoffDate) ?? cutoffDate
        }

        // Filter events that fall within our date range
        let recentEvents = events.filter { $0.timestamp >= cutoffDate }

        // Group by calendar day (accounting for leeway) and only include the last {days} unique days
        let eventsByDay = Dictionary(grouping: recentEvents) { event -> Date in
            let eventDay = calendar.startOfDay(for: event.timestamp)

            // If event is within leeway hours after midnight, count it as previous day
            if leewayHours > 0 {
                let hoursSinceMidnight = calendar.dateComponents([.hour], from: eventDay, to: event.timestamp).hour ?? 0
                if hoursSinceMidnight <= leewayHours {
                    return calendar.date(byAdding: .day, value: -1, to: eventDay) ?? eventDay
                }
            }

            return eventDay
        }

        // Get the last {days} unique calendar days
        let lastDays = Set(eventsByDay.keys.sorted().suffix(days))

        // Return events that fall on those days
        return recentEvents
            .filter { event in
                let eventDay = calendar.startOfDay(for: event.timestamp)
                let adjustedDay: Date

                if leewayHours > 0 {
                    let hoursSinceMidnight = calendar.dateComponents([.hour], from: eventDay, to: event.timestamp).hour ?? 0
                    if hoursSinceMidnight <= leewayHours {
                        adjustedDay = calendar.date(byAdding: .day, value: -1, to: eventDay) ?? eventDay
                    } else {
                        adjustedDay = eventDay
                    }
                } else {
                    adjustedDay = eventDay
                }

                return lastDays.contains(adjustedDay)
            }
            .sorted { $0.timestamp < $1.timestamp }
    }
}
