//
//  ExperiencePointsCalculatorTests.swift
//  SwiftfulGamificationTests
//
//  Tests for ExperiencePointsCalculator utility
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("ExperiencePointsCalculator Tests")
struct ExperiencePointsCalculatorTests {

    // MARK: - Basic XP Calculation Tests

    @Test("Calculates zero XP when no events")
    func testCalculatesZeroXPNoEvents() throws {
        // Given: Empty event array
        let events: [ExperiencePointsEvent] = []
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Should return blank XP data
        #expect(result.pointsToday == 0)
        #expect(result.eventsTodayCount == 0)
    }

    @Test("Calculates XP for single event")
    func testCalculatesXPForSingleEvent() throws {
        // Given: One event with 100 points
        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", points: 100)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Should have 100 points
        #expect(result.pointsToday == 100)
        #expect(result.eventsTodayCount == 1)
    }

    @Test("Calculates sum of multiple events")
    func testCalculatesSumOfMultipleEvents() throws {
        // Given: 5 events with different point values
        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", points: 100),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 250),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 50),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 300),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 75)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Should sum all points (775 total)
        #expect(result.pointsToday == 775)
        #expect(result.eventsTodayCount == 5)
    }

    @Test("Handles zero-point events")
    func testHandlesZeroPointEvents() throws {
        // Given: Events including zero-point events
        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", points: 100),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 0),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 50)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Should count events but not add zero points
        #expect(result.pointsToday == 150)
        #expect(result.eventsTodayCount == 3)
    }

    @Test("Handles large point values")
    func testHandlesLargePointValues() throws {
        // Given: Events with large point values
        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", points: 10000),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 25000),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 50000)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Should handle large sums
        #expect(result.pointsToday == 85000)
        #expect(result.eventsTodayCount == 3)
    }

    // MARK: - Metadata Filtering Tests

    @Test("getTotalPointsForMetadata filters by metadata field")
    func testGetTotalPointsForMetadata() throws {
        // Given: Events with different metadata
        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", points: 100, metadata: ["source": .string("quest")]),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 200, metadata: ["source": .string("battle")]),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 150, metadata: ["source": .string("quest")]),
            ExperiencePointsEvent.mock(experienceKey: "main", points: 300, metadata: ["source": .string("daily")])
        ]

        // When: Getting total points for "quest" source
        let questPoints = ExperiencePointsCalculator.getTotalPointsForMetadata(
            events: events,
            field: "source",
            value: .string("quest")
        )

        // Then: Should only count "quest" events (250 total)
        #expect(questPoints == 250)
    }

    @Test("Handles empty events array")
    func testHandlesEmptyEventArray() throws {
        // Given: Empty events
        let events: [ExperiencePointsEvent] = []
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Returns blank XP data
        #expect(result.pointsToday == 0)
        #expect(result.eventsTodayCount == 0)
        #expect(result.experienceKey == "main")
    }

    @Test("Handles events sorted in random order")
    func testHandlesRandomlySortedEvents() throws {
        // Given: Events today in random order
        let now = Date()
        let events = [
            ExperiencePointsEvent.mock(id: "3", experienceKey: "main", timestamp: now, points: 75),
            ExperiencePointsEvent.mock(id: "1", experienceKey: "main", timestamp: now, points: 100),
            ExperiencePointsEvent.mock(id: "4", experienceKey: "main", timestamp: now, points: 50),
            ExperiencePointsEvent.mock(id: "2", experienceKey: "main", timestamp: now, points: 200)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Should correctly sum all today's points regardless of order
        #expect(result.pointsToday == 425)
        #expect(result.eventsTodayCount == 4)
    }

    // MARK: - Edge Cases

    @Test("Handles single event with large value")
    func testHandlesSingleLargeValue() throws {
        // Given: Single event with large point value
        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", points: 1000000)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Should handle large value
        #expect(result.pointsToday == 1000000)
        #expect(result.eventsTodayCount == 1)
    }

    @Test("Handles very long event list")
    func testHandlesVeryLongEventList() throws {
        // Given: 1000 events
        let events = (0..<1000).map { i in
            ExperiencePointsEvent.mock(experienceKey: "main", points: 10)
        }
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Should correctly sum all events
        #expect(result.pointsToday == 10000)
        #expect(result.eventsTodayCount == 1000)
    }

    @Test("Returns correct experienceId in result")
    func testReturnsCorrectExperienceId() throws {
        // Given: Events for specific experienceId
        let events = [
            ExperiencePointsEvent.mock(experienceKey: "battle", points: 500)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "battle")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: Result should have correct experienceId
        #expect(result.experienceKey == "battle")
    }

    @Test("Sets updatedAt timestamp in result")
    func testSetsUpdatedAtTimestamp() throws {
        // Given: Events
        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", points: 100)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")
        let beforeCalculation = Date()

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        let afterCalculation = Date()

        // Then: updatedAt should be set to current time
        #expect(result.updatedAt != nil)
        if let updatedAt = result.updatedAt {
            #expect(updatedAt >= beforeCalculation)
            #expect(updatedAt <= afterCalculation)
        }
    }

    // MARK: - Time Window Tests

    @Test("pointsThisWeek calculates from Sunday to today")
    func testPointsThisWeekCalculation() throws {
        // Given: Events throughout the current week
        let timezone = TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = timezone // Match calculator's setup
        calendar.firstWeekday = 1 // Sunday

        let now = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!

        // Create events: Sunday (week start) and Today
        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: weekInterval.start, points: 100), // Sunday
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 300) // Today
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP (pass explicit timezone to match test calendar)
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now,
            timezone: timezone
        )

        // Then: Should sum all events from this week (400)
        #expect(result.pointsThisWeek == 400)
    }

    @Test("pointsLast7Days calculates rolling 7-day window")
    func testPointsLast7DaysCalculation() throws {
        // Given: Events over 10 days
        let calendar = Calendar.current
        let now = Date()

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 100), // Today
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .day, value: -3, to: now)!, points: 200), // 3 days ago
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .day, value: -6, to: now)!, points: 150), // 6 days ago
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .day, value: -8, to: now)!, points: 300) // 8 days ago (excluded)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should only include last 7 days (450)
        #expect(result.pointsLast7Days == 450)
    }

    @Test("pointsThisMonth calculates from 1st to today")
    func testPointsThisMonthCalculation() throws {
        // Given: Events throughout the month
        let calendar = Calendar.current
        let now = Date()
        let monthInterval = calendar.dateInterval(of: .month, for: now)!

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: monthInterval.start, points: 100), // 1st of month
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .day, value: 10, to: monthInterval.start)!, points: 250), // Mid month
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 150) // Today
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should sum all events this month
        #expect(result.pointsThisMonth == 500)
    }

    @Test("pointsLast30Days calculates rolling 30-day window")
    func testPointsLast30DaysCalculation() throws {
        // Given: Events over 40 days
        let calendar = Calendar.current
        let now = Date()

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 100), // Today
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .day, value: -15, to: now)!, points: 200), // 15 days ago
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .day, value: -29, to: now)!, points: 300), // 29 days ago
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .day, value: -35, to: now)!, points: 400) // 35 days ago (excluded)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should only include last 30 days (600)
        #expect(result.pointsLast30Days == 600)
    }

    @Test("pointsThisYear calculates from January 1st to today")
    func testPointsThisYearCalculation() throws {
        // Given: Events throughout the year
        let calendar = Calendar.current
        let now = Date()
        let yearInterval = calendar.dateInterval(of: .year, for: now)!

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: yearInterval.start, points: 100), // Jan 1
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .month, value: 6, to: yearInterval.start)!, points: 500), // Mid year
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 400) // Today
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should sum all events this year
        #expect(result.pointsThisYear == 1000)
    }

    @Test("pointsLast12Months calculates rolling 12-month window")
    func testPointsLast12MonthsCalculation() throws {
        // Given: Events over 15 months
        let calendar = Calendar.current
        let now = Date()

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 100), // Today
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .month, value: -6, to: now)!, points: 300), // 6 months ago
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .month, value: -11, to: now)!, points: 600), // 11 months ago
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .month, value: -13, to: now)!, points: 1000) // 13 months ago (excluded)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should only include last 12 months (1000)
        #expect(result.pointsLast12Months == 1000)
    }

    @Test("Time windows handle events outside range correctly")
    func testTimeWindowsExcludeOldEvents() throws {
        // Given: Old events and recent events
        let calendar = Calendar.current
        let now = Date()

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 100),
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .day, value: -10, to: now)!, points: 200), // 10 days ago
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .month, value: -2, to: now)!, points: 500), // 2 months ago
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: calendar.date(byAdding: .year, value: -2, to: now)!, points: 10000) // 2 years ago
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Different windows exclude different old events
        #expect(result.pointsToday == 100) // Only today
        #expect(result.pointsLast7Days == 100) // Today only (10 days ago is outside 7-day window)
        #expect(result.pointsLast30Days == 300) // Today + 10 days ago
        #expect(result.pointsThisYear == 800) // Today + 10 days + 2 months
        #expect(result.pointsLast12Months == 800) // Today + 10 days + 2 months
    }

    @Test("Time windows return zero for empty events")
    func testTimeWindowsWithEmptyEvents() throws {
        // Given: No events
        let events: [ExperiencePointsEvent] = []
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )

        // Then: All time windows should be 0
        #expect(result.pointsToday == 0)
        #expect(result.pointsThisWeek == 0)
        #expect(result.pointsLast7Days == 0)
        #expect(result.pointsThisMonth == 0)
        #expect(result.pointsLast30Days == 0)
        #expect(result.pointsThisYear == 0)
        #expect(result.pointsLast12Months == 0)
    }

    @Test("Time windows handle boundary dates correctly")
    func testTimeWindowsBoundaryConditions() throws {
        // Given: Events exactly at boundary dates
        let calendar = Calendar.current
        let now = Date()

        // Exactly 7 days ago
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        // Exactly 30 days ago
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: sevenDaysAgo, points: 100),
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: thirtyDaysAgo, points: 200)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Events at boundary should be included (>= comparison)
        #expect(result.pointsLast7Days == 100) // Includes event at exactly 7 days ago
        #expect(result.pointsLast30Days == 300) // Includes both events
    }

    @Test("pointsThisWeek only counts events from Sunday onwards")
    func testPointsThisWeekExcludesPreviousWeek() throws {
        // Given: Known date for testing (e.g., Wednesday)
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday

        let now = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
        let lastWeekSaturday = calendar.date(byAdding: .second, value: -1, to: weekInterval.start)!

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: lastWeekSaturday, points: 500), // Last week Saturday (excluded)
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: weekInterval.start, points: 100), // This week Sunday (included)
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 200) // Today (included)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should only count from Sunday onwards (300)
        #expect(result.pointsThisWeek == 300)
    }

    @Test("pointsThisMonth only counts events from 1st onwards")
    func testPointsThisMonthExcludesPreviousMonth() throws {
        // Given: Events in current and previous month
        let calendar = Calendar.current
        let now = Date()
        let monthInterval = calendar.dateInterval(of: .month, for: now)!
        let lastMonthEnd = calendar.date(byAdding: .second, value: -1, to: monthInterval.start)!

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: lastMonthEnd, points: 1000), // Last month (excluded)
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: monthInterval.start, points: 200), // 1st of month (included)
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 300) // Today (included)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should only count from 1st onwards (500)
        #expect(result.pointsThisMonth == 500)
    }

    @Test("pointsThisYear only counts events from January 1st onwards")
    func testPointsThisYearExcludesPreviousYear() throws {
        // Given: Events in current and previous year
        let calendar = Calendar.current
        let now = Date()
        let yearInterval = calendar.dateInterval(of: .year, for: now)!
        let lastYearEnd = calendar.date(byAdding: .second, value: -1, to: yearInterval.start)!

        let events = [
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: lastYearEnd, points: 5000), // Last year (excluded)
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: yearInterval.start, points: 1000), // Jan 1 (included)
            ExperiencePointsEvent.mock(experienceKey: "main", timestamp: now, points: 2000) // Today (included)
        ]
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config,
            currentDate: now
        )

        // Then: Should only count from Jan 1 onwards (3000)
        #expect(result.pointsThisYear == 3000)
    }

    // MARK: - Performance Tests

    @Test("Calculates efficiently with 10000+ events")
    func testPerformanceWith10000Events() throws {
        // Given: 10000 events
        let events = (0..<10000).map { i in
            ExperiencePointsEvent.mock(experienceKey: "main", points: i % 100)
        }
        let config = ExperiencePointsConfiguration(experienceKey: "main")

        // When: Calculating XP (measure performance)
        let startTime = Date()
        let result = ExperiencePointsCalculator.calculateExperiencePoints(
            events: events,
            configuration: config
        )
        let duration = Date().timeIntervalSince(startTime)

        // Then: Should complete in reasonable time (<1 second)
        #expect(result.eventsTodayCount == 10000)
        #expect(duration < 1.0) // Should be very fast
    }
}
