//
//  RecentEventsTests.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("Recent Events Tests")
struct RecentEventsTests {

    // MARK: - Basic Recent Events Tests

    @Test("Recent events includes last 60 days")
    func recentEventsIncludesLast60Days() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()

        // Create events for the last 15 days
        var events: [StreakEvent] = []
        for daysAgo in 0..<15 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            events.append(StreakEvent(
                id: UUID().uuidString,
                timestamp: date,
                timezone: timezone.identifier
            ))
        }

        let config = StreakConfiguration.mockDefault()
        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        // Should have all 15 days of events (within 60 day window)
        let recentEvents = streak.recentEvents ?? []
        let uniqueDays = Set(recentEvents.map { event in
            calendar.startOfDay(for: event.timestamp)
        })

        #expect(uniqueDays.count == 15)
    }

    @Test("Recent events returns empty when no events exist")
    func recentEventsReturnsEmptyWhenNoEvents() async throws {
        let config = StreakConfiguration.mockDefault()
        let (streak, _) = StreakCalculator.calculateStreak(
            events: [],
            freezes: [],
            configuration: config
        )

        // When no events exist, recentEvents should be empty or nil
        #expect(streak.recentEvents == nil || streak.recentEvents?.isEmpty == true)
    }

    @Test("Recent events includes freeze events")
    func recentEventsIncludesFreezeEvents() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()

        // Create regular events and freeze events
        var events: [StreakEvent] = []

        // Regular event today
        events.append(StreakEvent(
            id: UUID().uuidString,
            timestamp: now,
            timezone: timezone.identifier
        ))

        // Freeze event yesterday
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
            throw TestError.dateCalculationFailed
        }
        events.append(StreakEvent(
            id: UUID().uuidString,
            timestamp: yesterday,
            timezone: timezone.identifier,
            isFreeze: true,
            freezeId: "freeze123"
        ))

        let config = StreakConfiguration.mockDefault()
        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        let recentEvents = streak.recentEvents ?? []
        #expect(recentEvents.count == 2)
        #expect(recentEvents.contains(where: { $0.isFreeze }))
    }

    // MARK: - Leeway Tests

    @Test("Recent events accounts for leeway hours")
    func recentEventsAccountsForLeewayHours() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // Create events with leeway consideration
        var events: [StreakEvent] = []

        // Event at 1 AM today (within 3-hour leeway, should count as yesterday)
        guard let oneAM = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: todayStart) else {
            throw TestError.dateCalculationFailed
        }
        events.append(StreakEvent(
            id: "1am",
            timestamp: oneAM,
            timezone: timezone.identifier
        ))

        // Event at 4 AM today (outside leeway, counts as today)
        guard let fourAM = calendar.date(bySettingHour: 4, minute: 0, second: 0, of: todayStart) else {
            throw TestError.dateCalculationFailed
        }
        events.append(StreakEvent(
            id: "4am",
            timestamp: fourAM,
            timezone: timezone.identifier
        ))

        // Event yesterday afternoon
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
              let yesterdayAfternoon = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: yesterday) else {
            throw TestError.dateCalculationFailed
        }
        events.append(StreakEvent(
            id: "yesterday",
            timestamp: yesterdayAfternoon,
            timezone: timezone.identifier
        ))

        let config = StreakConfiguration(
            streakKey: "test",
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 3,
            freezeBehavior: .autoConsumeFreezes
        )

        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        let recentEvents = streak.recentEvents ?? []

        // All 3 events should be included
        #expect(recentEvents.count == 3)

        // The 1 AM event should be grouped with yesterday when we check calendar days
        let calendarDays = streak.getCalendarDaysWithEvents(timezone: timezone, leewayHours: 3)
        #expect(calendarDays.count == 2) // Yesterday and today (1 AM counts as yesterday)
    }

    @Test("Recent events with 0 leeway uses midnight boundary")
    func recentEventsWithZeroLeewayUsesMidnightBoundary() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // Event at 1 AM today
        guard let oneAM = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: todayStart) else {
            throw TestError.dateCalculationFailed
        }

        let events = [StreakEvent(
            id: "1am",
            timestamp: oneAM,
            timezone: timezone.identifier
        )]

        let config = StreakConfiguration(
            streakKey: "test",
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 0,
            freezeBehavior: .autoConsumeFreezes
        )

        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        let calendarDays = streak.getCalendarDaysWithEvents(timezone: timezone, leewayHours: 0)

        // With 0 leeway, 1 AM should count as today
        #expect(calendarDays.count == 1)
        #expect(calendarDays.first == todayStart)
    }

    // MARK: - Calendar Day Helpers Tests

    @Test("getCalendarDaysWithEvents returns correct days")
    func getCalendarDaysWithEventsReturnsCorrectDays() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()

        // Create events for specific days
        var events: [StreakEvent] = []
        for daysAgo in [0, 2, 4] { // Events on day 0, 2, and 4
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            events.append(StreakEvent(
                id: UUID().uuidString,
                timestamp: date,
                timezone: timezone.identifier
            ))
        }

        let config = StreakConfiguration.mockDefault()
        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        let calendarDays = streak.getCalendarDaysWithEvents(timezone: timezone)

        #expect(calendarDays.count == 3)
    }

    @Test("getCalendarDaysWithEventsThisWeek returns only this week")
    func getCalendarDaysWithEventsThisWeekReturnsOnlyThisWeek() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone
        calendar.firstWeekday = 1 // Sunday

        let now = Date()

        // Get the start of this week
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            throw TestError.dateCalculationFailed
        }

        // Create events: some this week, some last week
        var events: [StreakEvent] = []

        // Event this week (today)
        events.append(StreakEvent(
            id: "today",
            timestamp: now,
            timezone: timezone.identifier
        ))

        // Event this week (start of week)
        events.append(StreakEvent(
            id: "week_start",
            timestamp: weekInterval.start,
            timezone: timezone.identifier
        ))

        // Event last week (should be excluded)
        guard let lastWeek = calendar.date(byAdding: .day, value: -8, to: now) else {
            throw TestError.dateCalculationFailed
        }
        events.append(StreakEvent(
            id: "last_week",
            timestamp: lastWeek,
            timezone: timezone.identifier
        ))

        let config = StreakConfiguration.mockDefault()
        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        let calendarDays = streak.getCalendarDaysWithEventsThisWeek(timezone: timezone)

        // Should only include events from this week
        #expect(calendarDays.count <= 2) // At most 2 days this week

        // All days should be >= start of week
        for day in calendarDays {
            #expect(day >= weekInterval.start)
        }
    }

    @Test("getCalendarDaysWithEventsThisWeek with leeway")
    func getCalendarDaysWithEventsThisWeekWithLeeway() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone
        calendar.firstWeekday = 1 // Sunday

        let now = Date()

        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            throw TestError.dateCalculationFailed
        }

        // Event at 1 AM on Monday (first day of week after Sunday)
        guard let monday = calendar.date(byAdding: .day, value: 1, to: weekInterval.start),
              let mondayOneAM = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: monday) else {
            throw TestError.dateCalculationFailed
        }

        let events = [StreakEvent(
            id: "monday_1am",
            timestamp: mondayOneAM,
            timezone: timezone.identifier
        )]

        let config = StreakConfiguration(
            streakKey: "test",
            eventsRequiredPerDay: 1,
            useServerCalculation: false,
            leewayHours: 3,
            freezeBehavior: .autoConsumeFreezes
        )

        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        // With 3-hour leeway, 1 AM Monday should count as Sunday
        let calendarDays = streak.getCalendarDaysWithEventsThisWeek(timezone: timezone, leewayHours: 3)

        #expect(calendarDays.count == 1)
        // The day should be Sunday (start of week)
        #expect(calendarDays.first == weekInterval.start)
    }

    @Test("Empty recent events returns empty calendar days")
    func emptyRecentEventsReturnsEmptyCalendarDays() async throws {
        let streak = CurrentStreakData.blank(streakKey: "test")

        let calendarDays = streak.getCalendarDaysWithEvents()
        #expect(calendarDays.isEmpty)

        let thisWeek = streak.getCalendarDaysWithEventsThisWeek()
        #expect(thisWeek.isEmpty)
    }

    // MARK: - Edge Cases

    @Test("Recent events with multiple events same day")
    func recentEventsWithMultipleEventsSameDay() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()

        // Create 3 events on the same day
        var events: [StreakEvent] = []
        for hour in [9, 12, 18] {
            guard let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) else { continue }
            events.append(StreakEvent(
                id: UUID().uuidString,
                timestamp: date,
                timezone: timezone.identifier
            ))
        }

        let config = StreakConfiguration.mockDefault()
        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        let recentEvents = streak.recentEvents ?? []
        #expect(recentEvents.count == 3)

        // All events should map to the same calendar day
        let calendarDays = streak.getCalendarDaysWithEvents(timezone: timezone)
        #expect(calendarDays.count == 1)
    }

    @Test("Recent events sorted chronologically")
    func recentEventsSortedChronologically() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()

        // Create events in random order
        var events: [StreakEvent] = []
        for daysAgo in [5, 2, 8, 1, 3] {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            events.append(StreakEvent(
                id: UUID().uuidString,
                timestamp: date,
                timezone: timezone.identifier
            ))
        }

        let config = StreakConfiguration.mockDefault()
        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        let recentEvents = streak.recentEvents ?? []

        // Verify chronological order (oldest first)
        for i in 0..<(recentEvents.count - 1) {
            #expect(recentEvents[i].timestamp <= recentEvents[i + 1].timestamp)
        }
    }

    @Test("Recent events includes all days within 60 day window even with many events")
    func recentEventsIncludesAllDaysWithinWindow() async throws {
        let timezone = TimeZone(identifier: "America/New_York")!
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()

        // Create 30 events over 15 days (multiple per day)
        var events: [StreakEvent] = []
        for daysAgo in 0..<15 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            // 2 events per day
            for hour in [9, 18] {
                guard let eventDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) else { continue }
                events.append(StreakEvent(
                    id: UUID().uuidString,
                    timestamp: eventDate,
                    timezone: timezone.identifier
                ))
            }
        }

        let config = StreakConfiguration.mockDefault()
        let (streak, _) = StreakCalculator.calculateStreak(
            events: events,
            freezes: [],
            configuration: config
        )

        let recentEvents = streak.recentEvents ?? []

        // Should have events from all 15 unique days (within 60 day window)
        let uniqueDays = Set(recentEvents.map { event in
            calendar.startOfDay(for: event.timestamp)
        })

        #expect(uniqueDays.count == 15)

        // Calendar days should also return 15 days
        let calendarDays = streak.getCalendarDaysWithEvents(timezone: timezone)
        #expect(calendarDays.count == 15)
    }
}

enum TestError: Error {
    case dateCalculationFailed
}
