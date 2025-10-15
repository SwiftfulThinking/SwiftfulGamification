//
//  StreakCalculatorEdgeCaseTests.swift
//  SwiftfulGamificationTests
//
//  Critical edge case tests for streak calculation
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("StreakCalculator Edge Cases")
struct StreakCalculatorEdgeCaseTests {

    @Test("EDGE CASE: No event today, event yesterday should maintain streak (at risk)")
    func testNoEventTodayYesterdayEventMaintainsStreak() throws {
        // Given: Event yesterday, checking today (no event today yet)
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!

        let events = [
            StreakEvent.mock(dateCreated: yesterday)
        ]
        let config = StreakConfiguration(streakKey: "workout")

        // When: Calculating streak (today, no event yet)
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Streak should be 1 (yesterday's event still counts, at risk)
        // CRITICAL: This is the "at risk" state - last event was yesterday
        #expect(result.streak.currentStreak == 1, "Yesterday's event should still count as active streak (at risk)")
    }

    @Test("EDGE CASE: Streak start date wrong when freezes are used")
    func testStreakStartDateWithFreezes() throws {
        // Given: Gap filled with freezes
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            StreakEvent.mock(dateCreated: now),
            StreakEvent.mock(dateCreated: calendar.date(byAdding: .day, value: -3, to: now)!)
        ]
        let freezes = [
            StreakFreeze.mockUnused(id: "freeze-1"),
            StreakFreeze.mockUnused(id: "freeze-2")
        ]
        let config = StreakConfiguration(streakKey: "workout", freezeBehavior: .autoConsumeFreezes)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            freezes: freezes,
            configuration: config,
            currentDate: now
        )

        // Then: Streak = 4 (day 0, -1 freeze, -2 freeze, -3)
        #expect(result.streak.currentStreak == 4)

        // CRITICAL: streakStartDate should be 3 days ago (NOT nil)
        let threeDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -3, to: now)!)
        #expect(result.streak.streakStartDate != nil, "Streak start date should not be nil when freezes are used")

        if let startDate = result.streak.streakStartDate {
            let startDay = calendar.startOfDay(for: startDate)
            #expect(calendar.isDate(startDay, inSameDayAs: threeDaysAgo),
                   "Streak start should be 3 days ago (first day of streak)")
        }
    }

    @Test("EDGE CASE: Current day at 11:59 PM with no event should still count yesterday")
    func testLateNightNoEventYesterdayStillCounts() throws {
        // Given: Yesterday had event, currently 11:59 PM today (no event today)
        var calendar = Calendar.current
        calendar.timeZone = .current

        let todayLateNight = calendar.date(from: DateComponents(
            year: 2024, month: 1, day: 2,
            hour: 23, minute: 59
        ))!

        let yesterday = calendar.date(from: DateComponents(
            year: 2024, month: 1, day: 1,
            hour: 10, minute: 0
        ))!

        let events = [
            StreakEvent.mock(dateCreated: yesterday)
        ]
        let config = StreakConfiguration(streakKey: "workout")

        // When: Calculating at 11:59 PM
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: todayLateNight
        )

        // Then: Streak should be 1 (still at risk until midnight)
        #expect(result.streak.currentStreak == 1, "At 11:59 PM, yesterday's event should still count")
    }

    @Test("EDGE CASE: Midnight boundary - just after midnight with no event today")
    func testJustAfterMidnightNoEventTodayYesterdayStillCounts() throws {
        // Given: Yesterday had event, currently 12:01 AM today (just past midnight)
        var calendar = Calendar.current
        calendar.timeZone = .current

        let todayJustAfterMidnight = calendar.date(from: DateComponents(
            year: 2024, month: 1, day: 2,
            hour: 0, minute: 1
        ))!

        let yesterday = calendar.date(from: DateComponents(
            year: 2024, month: 1, day: 1,
            hour: 22, minute: 0
        ))!

        let events = [
            StreakEvent.mock(dateCreated: yesterday)
        ]
        let config = StreakConfiguration(streakKey: "workout", leewayHours: 0)

        // When: Calculating at 12:01 AM with NO leeway
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: todayJustAfterMidnight
        )

        // Then: Even at 12:01 AM, we're still "today" (Jan 2)
        // Yesterday's event (Jan 1) should still count as "at risk" until end of today
        // The streak only breaks if we reach end of Jan 2 with no event
        #expect(result.streak.currentStreak == 1, "At 12:01 AM, yesterday's event still counts (at risk state)")
    }

    @Test("EDGE CASE: Gap of 3+ days should break streak (no at-risk logic)")
    func testLargeGapBreaksStreak() throws {
        // Given: Last event was 3 days ago (no event for 3 days)
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!

        let events = [
            StreakEvent.mock(dateCreated: threeDaysAgo)
        ]
        let config = StreakConfiguration(streakKey: "workout")

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Streak should be 0 (broken - gap is 3 days, not just 1)
        // The "at risk" logic only applies to 1-day gaps
        #expect(result.streak.currentStreak == 0, "3-day gap should break streak (not at risk)")
    }

    @Test("EDGE CASE: Gap of 2 days should break streak (no freezes)")
    func testTwoDayGapBreaksStreak() throws {
        // Given: Last event was 2 days ago (no event for 2 days)
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!

        let events = [
            StreakEvent.mock(dateCreated: twoDaysAgo)
        ]
        let config = StreakConfiguration(streakKey: "workout", freezeBehavior: .noFreezes)

        // When: Calculating streak (no freezes)
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Streak should be 0 (broken - 2 day gap exceeds "at risk" threshold)
        #expect(result.streak.currentStreak == 0, "2-day gap should break streak without freezes")
    }

    @Test("EDGE CASE: Gap after active streak should still break correctly")
    func testGapAfterActiveStreakBreaks() throws {
        // Given: Events on day 0 (today), then gap, then day -4
        let now = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current

        let events = [
            StreakEvent.mock(dateCreated: now),
            StreakEvent.mock(dateCreated: calendar.date(byAdding: .day, value: -4, to: now)!)
        ]
        let config = StreakConfiguration(streakKey: "workout", freezeBehavior: .noFreezes)

        // When: Calculating streak
        let result = StreakCalculator.calculateStreak(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Streak should be 1 (only today counts, gap on days -1, -2, -3 breaks it)
        #expect(result.streak.currentStreak == 1, "Gap after today should break streak")
    }
}
