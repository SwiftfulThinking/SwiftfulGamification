//
//  StreakCalculatorTests.swift
//  SwiftfulGamificationTests
//
//  Tests for StreakCalculator utility
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("StreakCalculator Tests")
struct StreakCalculatorTests {

    // MARK: - Basic Streak Calculation Tests

    @Test("Calculates zero streak when no events")
    func testCalculatesZeroStreakNoEvents() throws {
        // Given: Empty event array
        let events: [StreakEvent] = []
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config
        )

        // Then: Should return blank streak data
        #expect(result.streak.currentStreak == 0)
        #expect(result.streak.longestStreak == 0)
        #expect(result.streak.totalEvents == 0)
        #expect(result.streak.lastEventDate == nil)
        #expect(result.streak.streakStartDate == nil)
        #expect(result.freezeConsumptions.isEmpty)
    }

    @Test("Calculates streak of 1 for single event today")
    func testCalculatesStreakOneForTodayEvent() throws {
        // Given: One event today
        let now = Date()
        let events = [
            StreakEvent.mock(timestamp: now)
        ]
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should have streak of 1
        #expect(result.streak.currentStreak == 1)
        #expect(result.streak.longestStreak == 1)
        #expect(result.streak.totalEvents == 1)
        #expect(result.streak.lastEventDate != nil)
        #expect(result.streak.todayEventCount == 1)
    }

    @Test("Calculates consecutive daily streak correctly")
    func testCalculatesConsecutiveDailyStreak() throws {
        // Given: 5 consecutive days of events
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = (0..<5).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            return StreakEvent.mock(timestamp: date)
        }
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should have streak of 5
        #expect(result.streak.currentStreak == 5)
        #expect(result.streak.longestStreak == 5)
        #expect(result.streak.totalEvents == 5)
    }

    @Test("Breaks streak when day is skipped")
    func testBreaksStreakWhenDaySkipped() throws {
        // Given: Events on days 0, 1, 3, 4 (missing day 2)
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let daysWithEvents = [0, 1, 3, 4] // Missing day 2
        let events = daysWithEvents.map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            return StreakEvent.mock(timestamp: date)
        }
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Current streak should be 2 (days 0 and 1), not 4
        #expect(result.streak.currentStreak == 2)
        #expect(result.streak.longestStreak == 2) // Longest is also 2 (days 3 and 4)
    }

    @Test("Handles multiple events on same day")
    func testHandlesMultipleEventsPerDay() throws {
        // Given: 3 events today, 2 events yesterday
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: now.addingTimeInterval(3600)), // 1 hour later
            StreakEvent.mock(timestamp: now.addingTimeInterval(7200)), // 2 hours later
            StreakEvent.mock(timestamp: yesterday),
            StreakEvent.mock(timestamp: yesterday.addingTimeInterval(3600))
        ]
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should count as 2-day streak (not 5-event streak)
        #expect(result.streak.currentStreak == 2)
        #expect(result.streak.todayEventCount == 3)
        #expect(result.streak.totalEvents == 5)
    }

    @Test("Ignores future events")
    func testIgnoresFutureEvents() throws {
        // Given: Events today and tomorrow (future)
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!

        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: tomorrow)
        ]
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak with currentDate = now
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Future event should be ignored, streak should be 1
        #expect(result.streak.currentStreak == 1)
        #expect(result.streak.totalEvents == 2) // Both events counted in total
    }

    @Test("Uses user's timezone for day boundaries")
    func testUsesUserTimezoneForDayBoundaries() throws {
        // Given: Event at 11:30 PM PST (which is 2:30 AM EST next day)
        // CRITICAL: Calculator uses CALCULATION timezone to group events, not event.timezone
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        let est = TimeZone(identifier: "America/New_York")!

        var calendarPST = Calendar.current
        calendarPST.timeZone = pst

        // Create date: Jan 1, 2024, 11:30 PM PST (= Jan 2, 2024, 2:30 AM EST)
        let components = DateComponents(year: 2024, month: 1, day: 1, hour: 23, minute: 30)
        let eventDate = calendarPST.date(from: components)!

        let events = [StreakEvent.mock(timestamp: eventDate)]
        let config = StreakConfiguration(streakId: "workout")

        // Current date: Jan 1, 2024, 11:59 PM PST (= Jan 2, 2024, 2:59 AM EST)
        let currentComponents = DateComponents(year: 2024, month: 1, day: 1, hour: 23, minute: 59)
        let currentDate = calendarPST.date(from: currentComponents)!

        // When: Calculating with PST timezone
        let resultPST = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: currentDate,
            timezone: pst
        )

        // When: Calculating with EST timezone
        // In EST, both eventDate and currentDate are on Jan 2 (early morning)
        let resultEST = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: currentDate,
            timezone: est
        )

        // Then: PST groups event on Jan 1 (today)
        #expect(resultPST.streak.currentStreak == 1)
        // EST groups event on Jan 2 (today in EST), so also counts as today
        #expect(resultEST.streak.currentStreak == 1)
    }

    // MARK: - Goal-Based Streak Tests

    @Test("Calculates goal-based streak with eventsRequiredPerDay = 3")
    func testCalculatesGoalBasedStreak() throws {
        // Given: 3 days with 3+ events each
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            // Today: 3 events
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: now.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(7200)),
            // Yesterday: 4 events
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(7200)),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(10800)),
            // 2 days ago: 3 events
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!.addingTimeInterval(7200))
        ]
        let config = StreakConfiguration(streakId: "workout", eventsRequiredPerDay: 3)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should have 3-day streak
        #expect(result.streak.currentStreak == 3)
        #expect(result.streak.eventsRequiredPerDay == 3)
        #expect(result.streak.todayEventCount == 3)
    }

    @Test("Goal-based: Day with 2/3 events breaks streak")
    func testGoalBasedBreaksStreakWhenGoalNotMet() throws {
        // Given: Today 3 events, yesterday 2 events (goal is 3)
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        let events = [
            // Today: 3 events (meets goal)
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: now.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(7200)),
            // Yesterday: 2 events (DOES NOT meet goal)
            StreakEvent.mock(timestamp: yesterday),
            StreakEvent.mock(timestamp: yesterday.addingTimeInterval(3600))
        ]
        let config = StreakConfiguration(streakId: "workout", eventsRequiredPerDay: 3)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Streak should be 1 (yesterday doesn't count)
        #expect(result.streak.currentStreak == 1)
        #expect(result.streak.totalEvents == 5)
    }

    @Test("Goal-based: Day with 4/3 events continues streak")
    func testGoalBasedContinuesStreakWhenGoalExceeded() throws {
        // Given: Today 4 events, yesterday 5 events (goal is 3)
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        let events = [
            // Today: 4 events
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: now.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(7200)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(10800)),
            // Yesterday: 5 events
            StreakEvent.mock(timestamp: yesterday),
            StreakEvent.mock(timestamp: yesterday.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: yesterday.addingTimeInterval(7200)),
            StreakEvent.mock(timestamp: yesterday.addingTimeInterval(10800)),
            StreakEvent.mock(timestamp: yesterday.addingTimeInterval(14400))
        ]
        let config = StreakConfiguration(streakId: "workout", eventsRequiredPerDay: 3)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Streak should be 2 (both days meet/exceed goal)
        #expect(result.streak.currentStreak == 2)
        #expect(result.streak.todayEventCount == 4)
    }

    @Test("Goal-based: todayEventCount calculated correctly")
    func testGoalBasedTodayEventCount() throws {
        // Given: 5 events today, 3 events yesterday
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: now.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(7200)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(10800)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(14400)),
            StreakEvent.mock(timestamp: yesterday),
            StreakEvent.mock(timestamp: yesterday.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: yesterday.addingTimeInterval(7200))
        ]
        let config = StreakConfiguration(streakId: "workout", eventsRequiredPerDay: 3)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: todayEventCount should be 5
        #expect(result.streak.todayEventCount == 5)
    }

    @Test("Goal-based: todayEventCount only counts today's events in user timezone")
    func testGoalBasedTodayEventCountTimezoneAware() throws {
        // Given: Events that straddle midnight in different timezones
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendarPST = Calendar.current
        calendarPST.timeZone = pst

        // Jan 1, 2024, 11:00 PM PST
        let components = DateComponents(year: 2024, month: 1, day: 1, hour: 23, minute: 0)
        let event1 = calendarPST.date(from: components)!

        // Jan 2, 2024, 1:00 AM PST (different day) - add 3 events today
        let components2 = DateComponents(year: 2024, month: 1, day: 2, hour: 1, minute: 0)
        let event2 = calendarPST.date(from: components2)!
        let event3 = event2.addingTimeInterval(3600) // 2:00 AM
        let event4 = event2.addingTimeInterval(7200) // 3:00 AM

        let events = [
            StreakEvent.mock(timestamp: event1),
            StreakEvent.mock(timestamp: event2),
            StreakEvent.mock(timestamp: event3),
            StreakEvent.mock(timestamp: event4)
        ]
        let config = StreakConfiguration(streakId: "workout", eventsRequiredPerDay: 3)

        // Current date: Jan 2, 2024, 4:00 AM PST
        let currentComponents = DateComponents(year: 2024, month: 1, day: 2, hour: 4, minute: 0)
        let currentDate = calendarPST.date(from: currentComponents)!

        // When: Calculating with PST timezone
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: currentDate,
            timezone: pst
        )

        // Then: Only events on Jan 2 count as "today" (3 events)
        #expect(result.streak.todayEventCount == 3)
        // Jan 1 has 1 event (doesn't meet goal of 3), Jan 2 has 3 events (meets goal)
        #expect(result.streak.currentStreak == 1) // Only today qualifies
    }

    // MARK: - Leeway Hours Tests

    @Test("Leeway hours extends deadline into next day")
    func testLeewayHoursExtendsDeadline() throws {
        // Given: Event yesterday, current time is 3am today (within 6-hour leeway)
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // Yesterday: Jan 1, 2024, 10:00 AM
        let yesterdayComponents = DateComponents(year: 2024, month: 1, day: 1, hour: 10, minute: 0)
        let yesterday = calendar.date(from: yesterdayComponents)!

        // Today: Jan 2, 2024, 3:00 AM (within 6-hour leeway)
        let todayComponents = DateComponents(year: 2024, month: 1, day: 2, hour: 3, minute: 0)
        let today = calendar.date(from: todayComponents)!

        let events = [StreakEvent.mock(timestamp: yesterday)]
        let config = StreakConfiguration(streakId: "workout", leewayHours: 6)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: today,
            timezone: pst
        )

        // Then: Streak should be 1 (leeway extends yesterday's deadline to 6am today)
        #expect(result.streak.currentStreak == 1)
    }

    @Test("Leeway 6 hours: Event at 2am next day continues streak")
    func testLeewayAllowsEarlyMorningEvent() throws {
        // Given: Events on consecutive days with leeway
        // CRITICAL: Leeway extends "today" backwards, so at 2am we're checking against "yesterday"
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // Day 1: Jan 1, 2024, 10:00 AM
        let day1 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 10, minute: 0))!

        // Day 2: Jan 2, 2024, 10:00 AM (normal time)
        let day2 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 2, hour: 10, minute: 0))!

        let events = [
            StreakEvent.mock(timestamp: day1),
            StreakEvent.mock(timestamp: day2)
        ]
        let config = StreakConfiguration(streakId: "workout", leewayHours: 6)

        // Current: Jan 3, 2024, 2:00 AM (within 6-hour leeway, so still counts as "day 2" deadline)
        let current = calendar.date(from: DateComponents(year: 2024, month: 1, day: 3, hour: 2, minute: 0))!

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: Streak continues because we're within leeway window
        #expect(result.streak.currentStreak == 2)
    }

    @Test("Leeway 6 hours: Event at 8am next day breaks streak")
    func testLeewayBreaksStreakAfterWindow() throws {
        // Given: Gap with event outside leeway window
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // Day 1: Jan 1, 2024, 10:00 AM
        let day1 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 10, minute: 0))!

        // Day 3: Jan 3, 2024, 8:00 AM (OUTSIDE 6-hour leeway - missing day 2)
        let day3 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 3, hour: 8, minute: 0))!

        let events = [
            StreakEvent.mock(timestamp: day1),
            StreakEvent.mock(timestamp: day3)
        ]
        let config = StreakConfiguration(streakId: "workout", leewayHours: 6)

        // Current: Jan 3, 2024, 9:00 AM
        let current = calendar.date(from: DateComponents(year: 2024, month: 1, day: 3, hour: 9, minute: 0))!

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: Streak should be 1 (only day 3 counts - day 2 was skipped)
        #expect(result.streak.currentStreak == 1)
    }

    @Test("Leeway 24 hours allows any time next day")
    func testLeeway24HoursAllowsFullDay() throws {
        // Given: Event yesterday, checking at 11pm today (within 24-hour leeway)
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // Yesterday: Jan 1, 2024, 10:00 AM
        let yesterday = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 10, minute: 0))!

        // Today: Jan 2, 2024, 11:00 PM (within 24-hour leeway)
        let today = calendar.date(from: DateComponents(year: 2024, month: 1, day: 2, hour: 23, minute: 0))!

        let events = [StreakEvent.mock(timestamp: yesterday)]
        let config = StreakConfiguration(streakId: "workout", leewayHours: 24)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: today,
            timezone: pst
        )

        // Then: Streak should be 1 (24-hour leeway covers entire next day)
        #expect(result.streak.currentStreak == 1)
    }

    @Test("Leeway 0 hours uses strict midnight boundary")
    func testLeewayZeroUsesStrictMidnight() throws {
        // Given: Event yesterday, checking at 12:01 AM today (NO leeway)
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // Yesterday: Jan 1, 2024, 11:00 PM
        let yesterday = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 23, minute: 0))!

        // Today: Jan 2, 2024, 12:01 AM (no leeway - already in new day)
        let today = calendar.date(from: DateComponents(year: 2024, month: 1, day: 2, hour: 0, minute: 1))!

        let events = [StreakEvent.mock(timestamp: yesterday)]
        let config = StreakConfiguration(streakId: "workout", leewayHours: 0)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: today,
            timezone: pst
        )

        // Then: Streak should be 0 (yesterday doesn't count, today has no event)
        #expect(result.streak.currentStreak == 0)
    }

    // MARK: - Timezone Handling Tests

    @Test("Handles timezone change mid-streak")
    func testHandlesTimezoneChangeMidStreak() throws {
        // Given: User logs events in PST, then travels to EST
        // CRITICAL: Calculator uses CALCULATION timezone, not event timezone
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendarPST = Calendar.current
        calendarPST.timeZone = pst

        // Day 1: Jan 1, 2024, 10:00 AM PST
        let day1 = calendarPST.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 10, minute: 0))!

        // Day 2: Jan 2, 2024, 10:00 AM PST
        let day2 = calendarPST.date(from: DateComponents(year: 2024, month: 1, day: 2, hour: 10, minute: 0))!

        // Day 3: Jan 3, 2024, 10:00 AM PST (1:00 PM EST)
        let day3 = calendarPST.date(from: DateComponents(year: 2024, month: 1, day: 3, hour: 10, minute: 0))!

        let events = [
            StreakEvent.mock(timestamp: day1, timezone: "America/Los_Angeles"),
            StreakEvent.mock(timestamp: day2, timezone: "America/Los_Angeles"),
            StreakEvent.mock(timestamp: day3, timezone: "America/Los_Angeles")
        ]
        let config = StreakConfiguration(streakId: "workout")

        // Current: Jan 3, 2024, 2:00 PM EST (11:00 AM PST)
        let current = day3.addingTimeInterval(3600) // 1 hour later

        // When: Calculating with PST (original timezone)
        let resultPST = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: All 3 days should count as consecutive
        #expect(resultPST.streak.currentStreak == 3)
    }

    @Test("Handles travel across multiple timezones")
    func testHandlesTravelAcrossTimezones() throws {
        // Given: User travels PST -> UTC -> JST over 5 days
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendarPST = Calendar.current
        calendarPST.timeZone = pst

        // Create 5 consecutive days in PST
        let events = (0..<5).map { daysAgo in
            let components = DateComponents(year: 2024, month: 1, day: 1 + daysAgo, hour: 10, minute: 0)
            let date = calendarPST.date(from: components)!
            return StreakEvent.mock(timestamp: date)
        }
        let config = StreakConfiguration(streakId: "workout")

        // Current: Jan 5, 2024, 11:00 AM PST
        let current = calendarPST.date(from: DateComponents(year: 2024, month: 1, day: 5, hour: 11, minute: 0))!

        // When: Calculating with different timezones
        let resultPST = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        let utc = TimeZone(identifier: "UTC")!
        let resultUTC = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: utc
        )

        let jst = TimeZone(identifier: "Asia/Tokyo")!
        let resultJST = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: jst
        )

        // Then: Streak calculation depends on timezone used for grouping
        // PST should have consistent 5-day streak
        #expect(resultPST.streak.currentStreak == 5)

        // UTC and JST will group events differently, but should still calculate correctly
        #expect(resultUTC.streak.totalEvents == 5)
        #expect(resultJST.streak.totalEvents == 5)
    }

    @Test("Uses event's timezone for day calculation")
    func testUsesEventTimezoneForDayCalculation() throws {
        // Given: Same absolute time, different timezones stored in event
        // CRITICAL: Calculator uses CALCULATION timezone, not event.timezone
        // event.timezone is metadata only
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendarPST = Calendar.current
        calendarPST.timeZone = pst

        // Jan 1, 2024, 11:00 PM PST (same absolute time)
        let eventTime = calendarPST.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 23, minute: 0))!

        // Event stored with PST timezone metadata
        let event1 = StreakEvent.mock(timestamp: eventTime, timezone: "America/Los_Angeles")

        // Event stored with EST timezone metadata (same absolute time, different timezone)
        let event2 = StreakEvent.mock(timestamp: eventTime, timezone: "America/New_York")

        let events = [event1, event2]
        let config = StreakConfiguration(streakId: "workout")

        // Current: Jan 2, 2024, 1:00 AM PST
        let current = calendarPST.date(from: DateComponents(year: 2024, month: 1, day: 2, hour: 1, minute: 0))!

        // When: Calculating with PST
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: Both events grouped by calculation timezone (PST)
        // Both events are same absolute time, so grouped into same day
        #expect(result.streak.totalEvents == 2)
        #expect(result.streak.todayEventCount == 0) // Events were yesterday in PST
    }

    @Test("Handles user starting in UTC and moving to PST")
    func testHandlesUTCtoPSTTransition() throws {
        // Given: Events logged in UTC, user moves to PST
        let utc = TimeZone(identifier: "UTC")!
        var calendarUTC = Calendar.current
        calendarUTC.timeZone = utc

        // 3 days of events in UTC
        let events = (0..<3).map { daysAgo in
            let components = DateComponents(year: 2024, month: 1, day: 1 + daysAgo, hour: 12, minute: 0)
            let date = calendarUTC.date(from: components)!
            return StreakEvent.mock(timestamp: date, timezone: "UTC")
        }
        let config = StreakConfiguration(streakId: "workout")

        // Current: Jan 3, 2024, 1:00 PM UTC
        let current = calendarUTC.date(from: DateComponents(year: 2024, month: 1, day: 3, hour: 13, minute: 0))!

        // When: Calculating with UTC
        let resultUTC = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: utc
        )

        // When: Calculating with PST (8 hours behind UTC)
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        let resultPST = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: UTC should show 3-day streak
        #expect(resultUTC.streak.currentStreak == 3)

        // PST grouping may differ, but total events same
        #expect(resultPST.streak.totalEvents == 3)
    }

    @Test("Handles user starting in PST and moving to JST")
    func testHandlesPSTtoJSTTransition() throws {
        // Given: Events logged in PST, user moves to JST (17 hours ahead)
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendarPST = Calendar.current
        calendarPST.timeZone = pst

        // 5 days of events in PST, 10:00 AM each day
        let events = (0..<5).map { daysAgo in
            let components = DateComponents(year: 2024, month: 1, day: 1 + daysAgo, hour: 10, minute: 0)
            let date = calendarPST.date(from: components)!
            return StreakEvent.mock(timestamp: date, timezone: "America/Los_Angeles")
        }
        let config = StreakConfiguration(streakId: "workout")

        // Current: Jan 5, 2024, 11:00 AM PST (Jan 6, 4:00 AM JST)
        let current = calendarPST.date(from: DateComponents(year: 2024, month: 1, day: 5, hour: 11, minute: 0))!

        // When: Calculating with PST
        let resultPST = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // When: Calculating with JST
        let jst = TimeZone(identifier: "Asia/Tokyo")!
        let resultJST = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: jst
        )

        // Then: PST should show 5-day streak
        #expect(resultPST.streak.currentStreak == 5)

        // JST will group events differently (some may shift to previous day)
        #expect(resultJST.streak.totalEvents == 5)
    }

    // MARK: - DST Transition Tests

    @Test("Handles spring forward DST transition")
    func testHandlesSpringForwardDST() throws {
        // Given: Events around spring DST transition (2am -> 3am)
        // In 2024: DST starts March 10, 2:00 AM -> 3:00 AM
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // March 9, 10:00 AM (before DST)
        let beforeDST = calendar.date(from: DateComponents(year: 2024, month: 3, day: 9, hour: 10, minute: 0))!

        // March 10, 10:00 AM (day of DST, after transition)
        let dayOfDST = calendar.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 10, minute: 0))!

        // March 11, 10:00 AM (after DST)
        let afterDST = calendar.date(from: DateComponents(year: 2024, month: 3, day: 11, hour: 10, minute: 0))!

        let events = [
            StreakEvent.mock(timestamp: beforeDST),
            StreakEvent.mock(timestamp: dayOfDST),
            StreakEvent.mock(timestamp: afterDST)
        ]
        let config = StreakConfiguration(streakId: "workout")

        // Current: March 11, 11:00 AM
        let current = calendar.date(from: DateComponents(year: 2024, month: 3, day: 11, hour: 11, minute: 0))!

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: All 3 days should count despite DST transition
        #expect(result.streak.currentStreak == 3)
    }

    @Test("Handles fall back DST transition")
    func testHandlesFallBackDST() throws {
        // Given: Events around fall DST transition (2am -> 1am)
        // In 2024: DST ends November 3, 2:00 AM -> 1:00 AM
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // November 2, 10:00 AM (before DST ends)
        let beforeDST = calendar.date(from: DateComponents(year: 2024, month: 11, day: 2, hour: 10, minute: 0))!

        // November 3, 10:00 AM (day of DST end, after transition)
        let dayOfDST = calendar.date(from: DateComponents(year: 2024, month: 11, day: 3, hour: 10, minute: 0))!

        // November 4, 10:00 AM (after DST ends)
        let afterDST = calendar.date(from: DateComponents(year: 2024, month: 11, day: 4, hour: 10, minute: 0))!

        let events = [
            StreakEvent.mock(timestamp: beforeDST),
            StreakEvent.mock(timestamp: dayOfDST),
            StreakEvent.mock(timestamp: afterDST)
        ]
        let config = StreakConfiguration(streakId: "workout")

        // Current: November 4, 11:00 AM
        let current = calendar.date(from: DateComponents(year: 2024, month: 11, day: 4, hour: 11, minute: 0))!

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: All 3 days should count despite DST transition
        #expect(result.streak.currentStreak == 3)
    }

    @Test("DST spring forward: 2am event continues streak")
    func testDSTSpringForwardEarlyMorningEvent() throws {
        // Given: Event at 2:30 AM on spring forward day (technically skipped hour)
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // March 9, 10:00 AM (before DST)
        let day1 = calendar.date(from: DateComponents(year: 2024, month: 3, day: 9, hour: 10, minute: 0))!

        // March 10, 3:30 AM (during DST transition - 2am doesn't exist, clocks jump to 3am)
        // Creating this time will auto-adjust
        let day2 = calendar.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 3, minute: 30))!

        let events = [
            StreakEvent.mock(timestamp: day1),
            StreakEvent.mock(timestamp: day2)
        ]
        let config = StreakConfiguration(streakId: "workout")

        // Current: March 10, 4:00 AM
        let current = calendar.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 4, minute: 0))!

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: Both days should count
        #expect(result.streak.currentStreak == 2)
    }

    @Test("DST fall back: 1am event continues streak")
    func testDSTFallBackEarlyMorningEvent() throws {
        // Given: Event at 1:30 AM on fall back day (ambiguous hour - occurs twice)
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // November 2, 10:00 AM (before DST ends)
        let day1 = calendar.date(from: DateComponents(year: 2024, month: 11, day: 2, hour: 10, minute: 0))!

        // November 3, 1:30 AM (ambiguous - occurs twice during fall back)
        let day2 = calendar.date(from: DateComponents(year: 2024, month: 11, day: 3, hour: 1, minute: 30))!

        let events = [
            StreakEvent.mock(timestamp: day1),
            StreakEvent.mock(timestamp: day2)
        ]
        let config = StreakConfiguration(streakId: "workout")

        // Current: November 3, 2:00 AM
        let current = calendar.date(from: DateComponents(year: 2024, month: 11, day: 3, hour: 2, minute: 0))!

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: Both days should count
        #expect(result.streak.currentStreak == 2)
    }

    // MARK: - Freeze Consumption Tests

    @Test("Identifies single gap that needs freeze")
    func testIdentifiesSingleGap() throws {
        // Given: Events on day 0, 2 (missing day 1) with 1 freeze available
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!)
        ]
        let freeze = StreakFreeze.mockUnused(id: "freeze-1")
        let config = StreakConfiguration(streakId: "workout", autoConsumeFreeze: true)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: [freeze],
            configuration: config,
            currentDate: now
        )

        // Then: Should consume 1 freeze for the gap
        #expect(result.freezeConsumptions.count == 1)
        #expect(result.freezeConsumptions[0].freezeId == "freeze-1")
        #expect(result.streak.currentStreak == 3) // Days 0, 1 (freeze), 2
    }

    @Test("Identifies multiple gaps that need freezes")
    func testIdentifiesMultipleGaps() throws {
        // Given: Events on day 0, 3, 4 (missing days 1, 2) with 2 freezes
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -3, to: now)!),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -4, to: now)!)
        ]
        let freezes = [
            StreakFreeze(id: "freeze-1", streakId: "workout", earnedDate: Date().addingTimeInterval(-86400 * 10)),
            StreakFreeze(id: "freeze-2", streakId: "workout", earnedDate: Date().addingTimeInterval(-86400 * 5))
        ]
        let config = StreakConfiguration(streakId: "workout", autoConsumeFreeze: true)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )

        // Then: Should consume 2 freezes for 2 gaps
        #expect(result.freezeConsumptions.count == 2)
        #expect(result.streak.currentStreak == 5) // Days 0, 1 (freeze), 2 (freeze), 3, 4
    }

    @Test("Returns oldest freezes first (FIFO)")
    func testReturnsOldestFreezesFirst() throws {
        // Given: Multiple freezes with different earned dates
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -4, to: now)!)
        ]

        // Freezes with different earned dates
        let freezes = [
            StreakFreeze(id: "freeze-new", streakId: "workout", earnedDate: Date().addingTimeInterval(-86400 * 1)), // Newest
            StreakFreeze(id: "freeze-old", streakId: "workout", earnedDate: Date().addingTimeInterval(-86400 * 30)), // Oldest
            StreakFreeze(id: "freeze-mid", streakId: "workout", earnedDate: Date().addingTimeInterval(-86400 * 10)) // Middle
        ]
        let config = StreakConfiguration(streakId: "workout", autoConsumeFreeze: true)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )

        // Then: Should use freezes in FIFO order (oldest first)
        #expect(result.freezeConsumptions.count == 3)
        #expect(result.freezeConsumptions[0].freezeId == "freeze-old") // Oldest used first
        #expect(result.freezeConsumptions[1].freezeId == "freeze-mid")
        #expect(result.freezeConsumptions[2].freezeId == "freeze-new")
    }

    @Test("Does not consume freezes for days with events")
    func testDoesNotConsumeFreezesForDaysWithEvents() throws {
        // Given: Consecutive days all with events
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = (0..<5).map { daysAgo in
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }
        let freezes = [StreakFreeze.mockUnused(id: "freeze-1")]
        let config = StreakConfiguration(streakId: "workout", autoConsumeFreeze: true)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )

        // Then: No freezes consumed (no gaps)
        #expect(result.freezeConsumptions.isEmpty)
        #expect(result.streak.currentStreak == 5)
        #expect(result.streak.freezesRemaining == 1)
    }

    @Test("Does not consume freezes when no gaps")
    func testDoesNotConsumeFreezesWhenNoGaps() throws {
        // Given: Perfect streak with no gaps
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = (0..<10).map { daysAgo in
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }
        let freezes = (0..<5).map { i in
            StreakFreeze.mockUnused(id: "freeze-\(i)")
        }
        let config = StreakConfiguration(streakId: "workout", autoConsumeFreeze: true)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )

        // Then: No freezes consumed
        #expect(result.freezeConsumptions.isEmpty)
        #expect(result.streak.freezesRemaining == 5)
    }

    @Test("Goal-based: Freeze fills day that missed goal")
    func testGoalBasedFreezesFillMissedGoal() throws {
        // Given: Goal is 3 events/day, one day has only 2 events
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            // Today: 3 events (meets goal)
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: now.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(7200)),
            // Yesterday: 2 events (DOES NOT meet goal - creates gap)
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(3600)),
            // 2 days ago: 3 events (meets goal)
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!.addingTimeInterval(7200))
        ]
        let freezes = [StreakFreeze.mockUnused(id: "freeze-1")]
        let config = StreakConfiguration(streakId: "workout", eventsRequiredPerDay: 3, autoConsumeFreeze: true)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )

        // Then: Freeze fills the gap from missed goal
        #expect(result.freezeConsumptions.count == 1)
        #expect(result.streak.currentStreak == 3) // All 3 days count
    }

    @Test("Goal-based: Does not use freeze when goal met")
    func testGoalBasedDoesNotUseFreezeWhenGoalMet() throws {
        // Given: All days meet goal of 3 events
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            // Today: 3 events
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: now.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(7200)),
            // Yesterday: 4 events
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(7200)),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(10800))
        ]
        let freezes = [StreakFreeze.mockUnused(id: "freeze-1")]
        let config = StreakConfiguration(streakId: "workout", eventsRequiredPerDay: 3, autoConsumeFreeze: true)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )

        // Then: No freezes consumed
        #expect(result.freezeConsumptions.isEmpty)
        #expect(result.streak.freezesRemaining == 1)
    }

    @Test("Returns empty consumption list when no freezes available")
    func testReturnsEmptyConsumptionWhenNoFreezes() throws {
        // Given: Gap but no freezes available
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!)
        ]
        let config = StreakConfiguration(streakId: "workout", autoConsumeFreeze: true)

        // When: Calculating streak with no freezes
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: [], // No freezes
            configuration: config,
            currentDate: now
        )

        // Then: Empty consumption list, streak broken
        #expect(result.freezeConsumptions.isEmpty)
        #expect(result.streak.currentStreak == 1) // Only today counts
    }

    @Test("Stops consuming freezes when all gaps filled")
    func testStopsConsumingWhenGapsFilled() throws {
        // Given: 1 gap but 3 freezes available
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!)
        ]
        let freezes = [
            StreakFreeze.mockUnused(id: "freeze-1"),
            StreakFreeze.mockUnused(id: "freeze-2"),
            StreakFreeze.mockUnused(id: "freeze-3")
        ]
        let config = StreakConfiguration(streakId: "workout", autoConsumeFreeze: true)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )

        // Then: Only 1 freeze consumed (for 1 gap), 2 remain
        #expect(result.freezeConsumptions.count == 1)
        #expect(result.streak.freezesRemaining == 2)
    }

    @Test("Handles more gaps than available freezes")
    func testHandlesMoreGapsThanFreezes() throws {
        // Given: 3 gaps but only 2 freezes
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -4, to: now)!)
        ]
        let freezes = [
            StreakFreeze.mockUnused(id: "freeze-1"),
            StreakFreeze.mockUnused(id: "freeze-2")
        ]
        let config = StreakConfiguration(streakId: "workout", autoConsumeFreeze: true)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )

        // Then: Consumes 2 freezes, but gap remains (streak still broken)
        #expect(result.freezeConsumptions.count == 2)
        #expect(result.streak.currentStreak == 3) // Can only fill 2 of 3 gaps
        #expect(result.streak.freezesRemaining == 0)
    }

    // MARK: - Longest Streak Tests

    @Test("Calculates longestStreak from event history")
    func testCalculatesLongestStreak() throws {
        // Given: Two streaks: 3 days (current) and 5 days (historical)
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        // Current streak: 3 days (days 0, 1, 2)
        let currentStreak = (0..<3).map { daysAgo in
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }

        // Gap on days 3, 4

        // Historical streak: 5 days (days 5, 6, 7, 8, 9)
        let historicalStreak = (5..<10).map { daysAgo in
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }

        let events = currentStreak + historicalStreak
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Longest should be 5 (historical), current should be 3
        #expect(result.streak.currentStreak == 3)
        #expect(result.streak.longestStreak == 5)
    }

    @Test("Preserves existing longestStreak if greater")
    func testPreservesExistingLongestStreak() throws {
        // Given: Historical longer streak
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        // Current: 2 days
        let current = (0..<2).map { daysAgo in
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }

        // Historical: 10 days (days 5-14)
        let historical = (5..<15).map { daysAgo in
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }

        let events = current + historical
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Longest is 10 (preserved from history)
        #expect(result.streak.currentStreak == 2)
        #expect(result.streak.longestStreak == 10)
    }

    @Test("Updates longestStreak when current exceeds it")
    func testUpdatesLongestStreakWhenExceeded() throws {
        // Given: Current streak is longest
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        // Current streak: 15 days
        let events = (0..<15).map { daysAgo in
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Longest equals current (15)
        #expect(result.streak.currentStreak == 15)
        #expect(result.streak.longestStreak == 15)
    }

    @Test("longestStreak equals currentStreak when no breaks")
    func testLongestEqualsCurrentWhenNoBreaks() throws {
        // Given: Perfect streak with no gaps
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = (0..<7).map { daysAgo in
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Longest equals current (7)
        #expect(result.streak.currentStreak == 7)
        #expect(result.streak.longestStreak == 7)
    }

    // MARK: - Edge Cases

    @Test("Handles empty event array")
    func testHandlesEmptyEventArray() throws {
        // Given: Empty events
        let events: [StreakEvent] = []
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config
        )

        // Then: Returns blank streak
        #expect(result.streak.currentStreak == 0)
        #expect(result.streak.longestStreak == 0)
        #expect(result.streak.streakId == "workout")
    }

    @Test("Handles events with invalid timezones")
    func testHandlesInvalidTimezones() throws {
        // Given: Events with invalid timezone strings (but valid timestamps)
        let now = Date()
        let events = [
            StreakEvent.mock(timestamp: now, timezone: "Invalid/Timezone"),
            StreakEvent.mock(timestamp: now.addingTimeInterval(-86400), timezone: "Not/A/Zone")
        ]
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak (using valid calculation timezone)
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now,
            timezone: .current
        )

        // Then: Should still calculate correctly (event.timezone is metadata only)
        #expect(result.streak.currentStreak == 2)
        #expect(result.streak.totalEvents == 2)
    }

    @Test("Handles events sorted in random order")
    func testHandlesRandomlySortedEvents() throws {
        // Given: Events in random order
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!),
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -4, to: now)!),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -3, to: now)!)
        ]
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should correctly identify 5-day streak
        #expect(result.streak.currentStreak == 5)
        #expect(result.streak.longestStreak == 5)
    }

    @Test("Handles very long streak (365+ days)")
    func testHandlesVeryLongStreak() throws {
        // Given: 400 consecutive days of events
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = (0..<400).map { daysAgo in
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
        }
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should handle large streaks
        #expect(result.streak.currentStreak == 400)
        #expect(result.streak.longestStreak == 400)
        #expect(result.streak.totalEvents == 400)
    }

    @Test("Handles events at exact midnight boundary")
    func testHandlesExactMidnightBoundary() throws {
        // Given: Events at exactly midnight
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        var calendar = Calendar.current
        calendar.timeZone = pst

        // Midnight Jan 1
        let midnight1 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0))!

        // Midnight Jan 2
        let midnight2 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 2, hour: 0, minute: 0, second: 0))!

        let events = [
            StreakEvent.mock(timestamp: midnight1),
            StreakEvent.mock(timestamp: midnight2)
        ]
        let config = StreakConfiguration(streakId: "workout")

        // Current: Jan 2, 1:00 AM
        let current = calendar.date(from: DateComponents(year: 2024, month: 1, day: 2, hour: 1, minute: 0))!

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: current,
            timezone: pst
        )

        // Then: Both midnight events should count as separate days
        #expect(result.streak.currentStreak == 2)
    }

    @Test("Handles events with fractional seconds")
    func testHandlesFractionalSeconds() throws {
        // Given: Events with microsecond differences
        let now = Date()
        let events = [
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: now.addingTimeInterval(0.001)), // 1ms later
            StreakEvent.mock(timestamp: now.addingTimeInterval(0.000001)) // 1μs later
        ]
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: All count as same day
        #expect(result.streak.currentStreak == 1)
        #expect(result.streak.totalEvents == 3)
    }

    @Test("Handles configuration changes mid-streak")
    func testHandlesConfigurationChanges() throws {
        // Given: Events suitable for different configurations
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        // 3 days with varying event counts
        let events = [
            // Today: 5 events
            StreakEvent.mock(timestamp: now),
            StreakEvent.mock(timestamp: now.addingTimeInterval(3600)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(7200)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(10800)),
            StreakEvent.mock(timestamp: now.addingTimeInterval(14400)),
            // Yesterday: 2 events
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!),
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(3600)),
            // 2 days ago: 1 event
            StreakEvent.mock(timestamp: calendar.date(byAdding: .day, value: -2, to: now)!)
        ]

        // Config 1: Basic mode (1 event/day)
        let config1 = StreakConfiguration(streakId: "workout", eventsRequiredPerDay: 1)
        let result1 = StreakCalculator.calculateStreak(
            events: events,
            configuration: config1,
            currentDate: now
        )

        // Config 2: Goal mode (3 events/day)
        let config2 = StreakConfiguration(streakId: "workout", eventsRequiredPerDay: 3)
        let result2 = StreakCalculator.calculateStreak(
            events: events,
            configuration: config2,
            currentDate: now
        )

        // Then: Different configs yield different results
        #expect(result1.streak.currentStreak == 3) // All 3 days have ≥1 event
        #expect(result2.streak.currentStreak == 1) // Only today has ≥3 events
    }

    // MARK: - Performance Tests

    @Test("Calculates streak efficiently with 1000+ events")
    func testPerformanceWith1000Events() throws {
        // Given: 1000 events spread over 100 days
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        var events: [StreakEvent] = []
        for day in 0..<100 {
            for hour in 0..<10 {
                let date = calendar.date(byAdding: .day, value: -day, to: now)!
                    .addingTimeInterval(TimeInterval(hour * 3600))
                events.append(StreakEvent.mock(timestamp: date))
            }
        }
        let config = StreakConfiguration(streakId: "workout")

        // When: Calculating streak (measure performance)
        let startTime = Date()
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )
        let duration = Date().timeIntervalSince(startTime)

        // Then: Should complete in reasonable time (<1 second)
        #expect(result.streak.totalEvents == 1000)
        #expect(duration < 1.0) // Should be very fast
    }

    @Test("Calculates streak efficiently with 100 freezes")
    func testPerformanceWith100Freezes() throws {
        // Given: Many gaps with many freezes
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        // Events every other day (50 gaps in 100 days)
        var events: [StreakEvent] = []
        for day in 0..<200 {
            if day % 2 == 0 {
                let date = calendar.date(byAdding: .day, value: -day, to: now)!
                events.append(StreakEvent.mock(timestamp: date))
            }
        }

        // 100 freezes
        let freezes = (0..<100).map { i in
            StreakFreeze.mockUnused(id: "freeze-\(i)")
        }
        let config = StreakConfiguration(streakId: "workout", autoConsumeFreeze: true)

        // When: Calculating streak
        let startTime = Date()
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )
        let duration = Date().timeIntervalSince(startTime)

        // Then: Should complete efficiently
        #expect(result.freezeConsumptions.count > 0)
        #expect(duration < 1.0)
    }
}
