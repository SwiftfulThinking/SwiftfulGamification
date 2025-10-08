//
//  CurrentStreakDataTests.swift
//  SwiftfulGamificationTests
//
//  Tests for CurrentStreakData model
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("CurrentStreakData Tests")
struct CurrentStreakDataTests {

    // MARK: - Initialization Tests

    @Test("Init with all fields creates valid instance")
    func testInitWithAllFields() throws {
        // Given: Values for all fields
        let streakId = "reading"
        let currentStreak = 15
        let longestStreak = 20
        let lastEventDate = Date()
        let lastEventTimezone = "America/New_York"
        let streakStartDate = Date().addingTimeInterval(-86400 * 15)
        let totalEvents = 50
        let freezesRemaining = 3
        let createdAt = Date().addingTimeInterval(-86400 * 30)
        let updatedAt = Date()
        let eventsRequiredPerDay = 2
        let todayEventCount = 1

        // When: Creating instance with all fields
        let data = CurrentStreakData(
            streakKey: streakId,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastEventDate: lastEventDate,
            lastEventTimezone: lastEventTimezone,
            streakStartDate: streakStartDate,
            totalEvents: totalEvents,
            freezesRemaining: freezesRemaining,
            createdAt: createdAt,
            updatedAt: updatedAt,
            eventsRequiredPerDay: eventsRequiredPerDay,
            todayEventCount: todayEventCount
        )

        // Then: All properties should be set correctly
        #expect(data.streakKey == streakId)
        #expect(data.currentStreak == currentStreak)
        #expect(data.longestStreak == longestStreak)
        #expect(data.lastEventDate == lastEventDate)
        #expect(data.lastEventTimezone == lastEventTimezone)
        #expect(data.streakStartDate == streakStartDate)
        #expect(data.totalEvents == totalEvents)
        #expect(data.freezesRemaining == freezesRemaining)
        #expect(data.createdAt == createdAt)
        #expect(data.updatedAt == updatedAt)
        #expect(data.eventsRequiredPerDay == eventsRequiredPerDay)
        #expect(data.todayEventCount == todayEventCount)
    }

    @Test("Blank factory creates zero streak")
    func testBlankFactoryCreatesZeroStreak() throws {
        // When: Creating blank streak
        let data = CurrentStreakData.blank(streakKey: "workout")

        // Then: Should have zero values
        #expect(data.streakKey == "workout")
        #expect(data.currentStreak == 0)
        #expect(data.longestStreak == 0)
        #expect(data.totalEvents == 0)
        #expect(data.freezesRemaining == 0)
        #expect(data.eventsRequiredPerDay == 1)
        #expect(data.todayEventCount == 0)
        #expect(data.lastEventDate == nil)
    }

    @Test("Mock factory creates valid streak")
    func testMockFactoryCreatesValidStreak() throws {
        // When: Creating mock streak
        let data = CurrentStreakData.mock()

        // Then: Should have default values
        #expect(data.streakKey == "workout")
        #expect(data.currentStreak == 5)
        #expect(data.longestStreak == 10)
        #expect(data.lastEventDate != nil)
        #expect(data.isValid == true)
    }

    @Test("Mock active creates streak with today's event")
    func testMockActiveCreatesValidStreak() throws {
        // When: Creating mockActive streak
        let data = CurrentStreakData.mockActive(currentStreak: 7)

        // Then: Should be active
        #expect(data.currentStreak == 7)
        #expect(data.isStreakActive == true)
        #expect(data.isStreakAtRisk == false)
        #expect(data.todayEventCount == 1)
    }

    @Test("Mock at risk creates streak with yesterday's event")
    func testMockAtRiskCreatesValidStreak() throws {
        // When: Creating mockAtRisk streak
        let data = CurrentStreakData.mockAtRisk(currentStreak: 5)

        // Then: Should be at risk
        #expect(data.currentStreak == 5)
        #expect(data.isStreakActive == true) // Still active (yesterday counts)
        #expect(data.isStreakAtRisk == true)
        #expect(data.todayEventCount == 0)
    }

    @Test("Mock goal-based creates streak with goal fields")
    func testMockGoalBasedCreatesValidStreak() throws {
        // When: Creating mockGoalBased streak
        let data = CurrentStreakData.mockGoalBased(eventsRequiredPerDay: 3, todayEventCount: 1)

        // Then: Should have goal-based fields
        #expect(data.eventsRequiredPerDay == 3)
        #expect(data.todayEventCount == 1)
        #expect(data.isGoalMet == false) // 1/3 not met
        #expect(data.goalProgress > 0.3 && data.goalProgress < 0.4)
    }

    // MARK: - Codable Tests

    @Test("Encodes to snake_case keys")
    func testEncodesToSnakeCase() throws {
        // Given: Streak data with all fields
        let data = CurrentStreakData.mock()

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = try encoder.encode(data)
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        // Then: Should use snake_case keys
        #expect(json["streak_id"] != nil)
        #expect(json["current_streak"] != nil)
        #expect(json["longest_streak"] != nil)
        #expect(json["last_event_date"] != nil)
        #expect(json["last_event_timezone"] != nil)
        #expect(json["events_required_per_day"] != nil)
        #expect(json["today_event_count"] != nil)

        // And: Should not contain camelCase keys
        #expect(json["streakId"] == nil)
        #expect(json["currentStreak"] == nil)
        #expect(json["longestStreak"] == nil)
    }

    @Test("Decodes from snake_case keys")
    func testDecodesFromSnakeCase() throws {
        // Given: Streak data
        let original = CurrentStreakData.mock(streakKey: "reading", currentStreak: 10)

        // When: Encoding then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CurrentStreakData.self, from: data)

        // Then: Should decode correctly
        #expect(decoded.streakKey == "reading")
        #expect(decoded.currentStreak == 10)
    }

    @Test("Roundtrip encoding preserves all data")
    func testRoundtripPreservesData() throws {
        // Given: Original streak data
        let original = CurrentStreakData.mock()

        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CurrentStreakData.self, from: data)

        // Then: Should preserve all data
        #expect(decoded == original)
    }

    @Test("Decodes with missing optional fields")
    func testDecodesWithMissingFields() throws {
        // Given: JSON with only required field
        let json = """
        {
            "streak_id": "minimal"
        }
        """
        let data = json.data(using: .utf8)!

        // When: Decoding
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CurrentStreakData.self, from: data)

        // Then: Should decode with nil optional fields
        #expect(decoded.streakKey == "minimal")
        #expect(decoded.currentStreak == nil)
        #expect(decoded.longestStreak == nil)
        #expect(decoded.lastEventDate == nil)
    }

    // MARK: - Computed Property Tests

    @Test("status returns .noEvents when no lastEventDate")
    func testStatusNoEvents() throws {
        // Given: Streak with no events
        let data = CurrentStreakData.blank(streakKey: "test")

        // Then: Status should be noEvents
        if case .noEvents = data.status {
            // Success
        } else {
            #expect(Bool(false), "Expected .noEvents status")
        }
    }

    @Test("status returns .active when event today")
    func testStatusActiveToday() throws {
        // Given: Streak with event today
        let data = CurrentStreakData.mockActive()

        // Then: Status should be active
        if case .active = data.status {
            // Success
        } else {
            #expect(Bool(false), "Expected .active status")
        }
    }

    @Test("status returns .atRisk when event yesterday")
    func testStatusAtRisk() throws {
        // Given: Streak with event yesterday
        let data = CurrentStreakData.mockAtRisk()

        // Then: Status should be atRisk
        if case .atRisk = data.status {
            // Success
        } else {
            #expect(Bool(false), "Expected .atRisk status")
        }
    }

    @Test("status returns .broken when 2+ days since event")
    func testStatusBroken() throws {
        // Given: Streak with event 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let data = CurrentStreakData(
            streakKey: "test",
            lastEventDate: threeDaysAgo,
            lastEventTimezone: TimeZone.current.identifier
        )

        // Then: Status should be broken
        if case .broken = data.status {
            // Success
        } else {
            #expect(Bool(false), "Expected .broken status")
        }
    }

    @Test("isStreakActive true when event today")
    func testIsStreakActiveTrueToday() throws {
        // Given: Streak with event today
        let data = CurrentStreakData.mockActive()

        // Then: Should be active
        #expect(data.isStreakActive == true)
    }

    @Test("isStreakActive true when event yesterday")
    func testIsStreakActiveTrueYesterday() throws {
        // Given: Streak with event yesterday
        let data = CurrentStreakData.mockAtRisk()

        // Then: Should still be active (yesterday counts)
        #expect(data.isStreakActive == true)
    }

    @Test("isStreakActive false when 2+ days ago")
    func testIsStreakActiveFalse() throws {
        // Given: Streak with event 2 days ago
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let data = CurrentStreakData(
            streakKey: "test",
            lastEventDate: twoDaysAgo,
            lastEventTimezone: TimeZone.current.identifier
        )

        // Then: Should not be active
        #expect(data.isStreakActive == false)
    }

    @Test("isStreakAtRisk true when event yesterday")
    func testIsStreakAtRiskTrue() throws {
        // Given: Streak with event yesterday
        let data = CurrentStreakData.mockAtRisk()

        // Then: Should be at risk
        #expect(data.isStreakAtRisk == true)
    }

    @Test("isStreakAtRisk false when event today")
    func testIsStreakAtRiskFalse() throws {
        // Given: Streak with event today
        let data = CurrentStreakData.mockActive()

        // Then: Should not be at risk
        #expect(data.isStreakAtRisk == false)
    }

    @Test("daysSinceLastEvent calculated correctly")
    func testDaysSinceLastEvent() throws {
        // Given: Streak with event 3 days ago
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let data = CurrentStreakData(
            streakKey: "test",
            lastEventDate: threeDaysAgo,
            lastEventTimezone: TimeZone.current.identifier
        )

        // Then: Should calculate 3 days
        #expect(data.daysSinceLastEvent == 3)
    }

    @Test("daysSinceLastEvent nil when no lastEventDate")
    func testDaysSinceLastEventNil() throws {
        // Given: Streak with no events
        let data = CurrentStreakData.blank(streakKey: "test")

        // Then: daysSinceLastEvent should be nil
        #expect(data.daysSinceLastEvent == nil)
    }

    // MARK: - Freeze Helper Properties

    @Test("freezesNeededToSaveStreak returns 0 when streak is active")
    func testFreezesNeededWhenActive() throws {
        // Given: Last event today
        let data = CurrentStreakData.mock(lastEventDate: Date())

        // Then: No freezes needed
        #expect(data.freezesNeededToSaveStreak == 0)
    }

    @Test("freezesNeededToSaveStreak returns gap size when broken")
    func testFreezesNeededWhenBroken() throws {
        // Given: Last event 3 days ago (2-day gap)
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: threeDaysAgo)

        // Then: Need 2 freezes (gap of 2 days)
        #expect(data.freezesNeededToSaveStreak == 2)
    }

    @Test("freezesNeededToSaveStreak handles 1-day gap")
    func testFreezesNeededOneDayGap() throws {
        // Given: Last event 2 days ago (1-day gap)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: twoDaysAgo)

        // Then: Need 1 freeze
        #expect(data.freezesNeededToSaveStreak == 1)
    }

    @Test("canStreakBeSaved returns true when active")
    func testCanSaveWhenActive() throws {
        // Given: Active streak
        let data = CurrentStreakData.mock(lastEventDate: Date(), freezesRemaining: 0)

        // Then: Can be saved (no freeze needed)
        #expect(data.canStreakBeSaved == true)
    }

    @Test("canStreakBeSaved returns true with sufficient freezes")
    func testCanSaveWithSufficientFreezes() throws {
        // Given: 2-day gap, 3 freezes available
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: threeDaysAgo, freezesRemaining: 3)

        // Then: Can be saved
        #expect(data.canStreakBeSaved == true)
    }

    @Test("canStreakBeSaved returns true with exact freezes")
    func testCanSaveWithExactFreezes() throws {
        // Given: 2-day gap, exactly 2 freezes
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: threeDaysAgo, freezesRemaining: 2)

        // Then: Can be saved
        #expect(data.canStreakBeSaved == true)
    }

    @Test("canStreakBeSaved returns false with insufficient freezes")
    func testCannotSaveWithInsufficientFreezes() throws {
        // Given: 3-day gap, only 2 freezes available
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: fourDaysAgo, freezesRemaining: 2)

        // Then: Cannot be saved
        #expect(data.canStreakBeSaved == false)
    }

    @Test("canStreakBeSaved returns false with zero freezes and broken streak")
    func testCannotSaveWithNoFreezes() throws {
        // Given: Broken streak, no freezes
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: threeDaysAgo, freezesRemaining: 0)

        // Then: Cannot be saved
        #expect(data.canStreakBeSaved == false)
    }

    @Test("shouldPromptFreezeUsage returns false when streak active")
    func testShouldNotPromptWhenActive() throws {
        // Given: Active streak
        let data = CurrentStreakData.mock(lastEventDate: Date(), freezesRemaining: 5)

        // Then: Should not prompt
        #expect(data.shouldPromptFreezeUsage == false)
    }

    @Test("shouldPromptFreezeUsage returns false when at risk")
    func testShouldNotPromptWhenAtRisk() throws {
        // Given: At risk (yesterday)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: yesterday, freezesRemaining: 5)

        // Then: Should not prompt (not broken yet)
        #expect(data.shouldPromptFreezeUsage == false)
    }

    @Test("shouldPromptFreezeUsage returns true when broken and saveable")
    func testShouldPromptWhenBrokenAndSaveable() throws {
        // Given: Broken streak (3 days ago = 2-day gap), 2 freezes available
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: threeDaysAgo, freezesRemaining: 2)

        // Then: Should prompt (broken but can be saved)
        #expect(data.shouldPromptFreezeUsage == true)
    }

    @Test("shouldPromptFreezeUsage returns false when broken but not saveable")
    func testShouldNotPromptWhenBrokenButNotSaveable() throws {
        // Given: Broken streak (5 days ago = 4-day gap), only 2 freezes
        let fiveDaysAgo = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: fiveDaysAgo, freezesRemaining: 2)

        // Then: Should not prompt (cannot be saved)
        #expect(data.shouldPromptFreezeUsage == false)
    }

    @Test("shouldPromptFreezeUsage returns false when broken with no freezes")
    func testShouldNotPromptWhenNoFreezes() throws {
        // Given: Broken streak, no freezes
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let data = CurrentStreakData.mock(lastEventDate: threeDaysAgo, freezesRemaining: 0)

        // Then: Should not prompt
        #expect(data.shouldPromptFreezeUsage == false)
    }

    // MARK: - Goal-Based Computed Properties

    @Test("isGoalMet true when todayEventCount >= eventsRequiredPerDay")
    func testIsGoalMetTrue() throws {
        // Given: Goal-based streak with goal met
        let data = CurrentStreakData.mockGoalBased(eventsRequiredPerDay: 3, todayEventCount: 3)

        // Then: Goal should be met
        #expect(data.isGoalMet == true)
    }

    @Test("isGoalMet false when todayEventCount < eventsRequiredPerDay")
    func testIsGoalMetFalse() throws {
        // Given: Goal-based streak with goal not met
        let data = CurrentStreakData.mockGoalBased(eventsRequiredPerDay: 3, todayEventCount: 1)

        // Then: Goal should not be met
        #expect(data.isGoalMet == false)
    }

    @Test("isGoalMet true for basic streak (1 event)")
    func testIsGoalMetBasicStreak() throws {
        // Given: Basic streak (eventsRequiredPerDay = 1) with 1 event today
        let data = CurrentStreakData.mockActive()

        // Then: Goal should be met
        #expect(data.isGoalMet == true)
    }

    @Test("goalProgress calculated correctly")
    func testGoalProgress() throws {
        // Given: Goal-based streak with 2/5 events
        let data = CurrentStreakData.mockGoalBased(eventsRequiredPerDay: 5, todayEventCount: 2)

        // Then: Progress should be 0.4 (2/5)
        #expect(abs(data.goalProgress - 0.4) < 0.01)
    }

    @Test("goalProgress caps at 1.0")
    func testGoalProgressCapsAtOne() throws {
        // Given: Goal-based streak with more events than required
        let data = CurrentStreakData.mockGoalBased(eventsRequiredPerDay: 3, todayEventCount: 5)

        // Then: Progress should cap at 1.0
        #expect(data.goalProgress == 1.0)
    }

    // MARK: - Validation Tests

    @Test("isValid true for valid data")
    func testIsValidTrue() throws {
        // Given: Valid streak data
        let data = CurrentStreakData.mock()

        // Then: Should be valid
        #expect(data.isValid == true)
    }

    @Test("isValid false when currentStreak negative")
    func testIsValidFalseNegativeStreak() throws {
        // Given: Streak with negative currentStreak
        let data = CurrentStreakData(streakKey: "test", currentStreak: -1)

        // Then: Should be invalid
        #expect(data.isValid == false)
    }

    @Test("isValid false when longestStreak < currentStreak")
    func testIsValidFalseLongestLessThanCurrent() throws {
        // Given: Streak where longest < current (invalid)
        let data = CurrentStreakData(
            streakKey: "test",
            currentStreak: 10,
            longestStreak: 5
        )

        // Then: Should be invalid
        #expect(data.isValid == false)
    }

    @Test("isValid false when invalid timezone")
    func testIsValidFalseInvalidTimezone() throws {
        // Given: Streak with invalid timezone
        let data = CurrentStreakData(
            streakKey: "test",
            lastEventTimezone: "Invalid/Timezone"
        )

        // Then: Should be invalid
        #expect(data.isValid == false)
    }

    @Test("isValid false when eventsRequiredPerDay < 1")
    func testIsValidFalseEventsRequired() throws {
        // Given: Streak with eventsRequiredPerDay = 0
        let data = CurrentStreakData(
            streakKey: "test",
            eventsRequiredPerDay: 0
        )

        // Then: Should be invalid
        #expect(data.isValid == false)
    }

    // MARK: - Analytics Tests

    @Test("eventParameters includes all streak fields")
    func testEventParametersIncludesAllFields() throws {
        // Given: Streak with known values
        let data = CurrentStreakData.mock(streakKey: "meditation", currentStreak: 7)

        // When: Getting event parameters
        let params = data.eventParameters

        // Then: Should include all fields with current_streak_ prefix
        #expect(params["current_streak_streak_id"] as? String == "meditation")
        #expect(params["current_streak_current_streak"] as? Int == 7)
        #expect(params["current_streak_is_streak_active"] as? Bool != nil)
        #expect(params["current_streak_is_goal_met"] as? Bool != nil)
        #expect(params["current_streak_goal_progress"] as? Double != nil)
    }

    @Test("eventParameters prefixed with current_streak_")
    func testEventParametersPrefixed() throws {
        // Given: Streak with specific streakId
        let data = CurrentStreakData.mock(streakKey: "running")

        // When: Getting event parameters
        let params = data.eventParameters

        // Then: Should prefix all keys with current_streak_
        #expect(params["current_streak_streak_id"] as? String == "running")
        #expect(params["current_streak_current_streak"] != nil)
        #expect(params["current_streak_longest_streak"] != nil)
        #expect(params["current_streak_is_streak_active"] != nil)
    }

    @Test("eventParameters includes computed properties")
    func testEventParametersIncludesComputedProperties() throws {
        // Given: Active streak
        let data = CurrentStreakData.mockActive()

        // When: Getting event parameters
        let params = data.eventParameters

        // Then: Should include computed properties with current_streak_ prefix
        #expect(params["current_streak_is_streak_active"] as? Bool == true)
        #expect(params["current_streak_is_goal_met"] != nil)
        #expect(params["current_streak_goal_progress"] != nil)
    }

    // MARK: - Equatable Tests

    @Test("Same data makes instances equal")
    func testEquatableEqual() throws {
        // Given: Two instances with identical data
        let date = Date()
        let data1 = CurrentStreakData(
            streakKey: "test",
            currentStreak: 5,
            longestStreak: 10,
            lastEventDate: date
        )
        let data2 = CurrentStreakData(
            streakKey: "test",
            currentStreak: 5,
            longestStreak: 10,
            lastEventDate: date
        )

        // Then: Should be equal
        #expect(data1 == data2)
    }

    @Test("Different streakId makes instances unequal")
    func testEquatableUnequalStreakId() throws {
        // Given: Two instances differing only in streakId
        let data1 = CurrentStreakData(streakKey: "workout")
        let data2 = CurrentStreakData(streakKey: "reading")

        // Then: Should not be equal
        #expect(data1 != data2)
    }

    @Test("Different currentStreak makes instances unequal")
    func testEquatableUnequalCurrentStreak() throws {
        // Given: Two instances differing only in currentStreak
        let data1 = CurrentStreakData(streakKey: "test", currentStreak: 5)
        let data2 = CurrentStreakData(streakKey: "test", currentStreak: 10)

        // Then: Should not be equal
        #expect(data1 != data2)
    }

    // MARK: - Stale Data Tests

    @Test("isDataStale returns true when updatedAt is nil")
    func testIsDataStaleWhenUpdatedAtNil() throws {
        // Given: Streak with no updatedAt
        let data = CurrentStreakData(
            streakKey: "test",
            currentStreak: 5,
            updatedAt: nil
        )

        // Then: Should be stale
        #expect(data.isDataStale == true)
    }

    @Test("isDataStale returns false when updated less than 1 hour ago")
    func testIsDataStaleWhenRecentlyUpdated() throws {
        // Given: Streak updated 30 minutes ago
        let thirtyMinutesAgo = Date().addingTimeInterval(-30 * 60)
        let data = CurrentStreakData(
            streakKey: "test",
            currentStreak: 5,
            updatedAt: thirtyMinutesAgo
        )

        // Then: Should not be stale
        #expect(data.isDataStale == false)
    }

    @Test("isDataStale returns true when updated over 1 hour ago")
    func testIsDataStaleWhenOldUpdate() throws {
        // Given: Streak updated 2 hours ago
        let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)
        let data = CurrentStreakData(
            streakKey: "test",
            currentStreak: 5,
            updatedAt: twoHoursAgo
        )

        // Then: Should be stale
        #expect(data.isDataStale == true)
    }

    @Test("isDataStale boundary: exactly 1 hour ago")
    func testIsDataStaleBoundary() throws {
        // Given: Streak updated exactly 1 hour ago
        let oneHourAgo = Date().addingTimeInterval(-60 * 60)
        let data = CurrentStreakData(
            streakKey: "test",
            currentStreak: 5,
            updatedAt: oneHourAgo
        )

        // Then: Should be stale (> 1 hour threshold)
        #expect(data.isDataStale == true)
    }

    @Test("isDataStale with fresh update")
    func testIsDataStaleWithCurrentUpdate() throws {
        // Given: Streak updated now
        let data = CurrentStreakData(
            streakKey: "test",
            currentStreak: 5,
            updatedAt: Date()
        )

        // Then: Should not be stale
        #expect(data.isDataStale == false)
    }

    @Test("isDataStale with 24 hour old data")
    func testIsDataStaleWith24HourOldData() throws {
        // Given: Streak updated 24 hours ago
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        let data = CurrentStreakData(
            streakKey: "test",
            currentStreak: 5,
            updatedAt: oneDayAgo
        )

        // Then: Should be stale
        #expect(data.isDataStale == true)
    }
}
