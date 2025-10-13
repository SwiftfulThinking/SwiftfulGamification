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
