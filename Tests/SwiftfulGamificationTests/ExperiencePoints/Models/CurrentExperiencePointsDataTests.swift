//
//  CurrentExperiencePointsDataTests.swift
//  SwiftfulGamificationTests
//
//  Tests for CurrentExperiencePointsData model
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("CurrentExperiencePointsData Tests")
struct CurrentExperiencePointsDataTests {

    // MARK: - Initialization Tests

    @Test("Init with all fields creates valid instance")
    func testInitWithAllFields() throws {
        // Given: Values for all fields
        let experienceId = "main"
        let totalPoints = 5000
        let totalEvents = 150
        let createdAt = Date().addingTimeInterval(-86400 * 30)
        let updatedAt = Date()

        // When: Creating instance with all fields
        let data = CurrentExperiencePointsData(
            experienceKey: experienceId,
            pointsToday: totalPoints,
            eventsTodayCount: totalEvents,
            dateCreated: createdAt,
            dateUpdated: updatedAt
        )

        // Then: All properties should be set correctly
        #expect(data.experienceKey == experienceId)
        #expect(data.pointsToday == totalPoints)
        #expect(data.eventsTodayCount == totalEvents)
        #expect(data.dateCreated == createdAt)
        #expect(data.dateUpdated == updatedAt)
    }

    @Test("Blank factory creates zero data")
    func testBlankFactoryCreatesZeroData() throws {
        // When: Creating blank data
        let data = CurrentExperiencePointsData.blank(experienceKey: "main")

        // Then: Should have zero values
        #expect(data.experienceKey == "main")
        #expect(data.pointsToday == 0)
        #expect(data.eventsTodayCount == 0)
    }

    @Test("Mock factory creates valid data")
    func testMockFactoryCreatesValidData() throws {
        // When: Creating mock data
        let data = CurrentExperiencePointsData.mock()

        // Then: Should have default values
        #expect(data.experienceKey == "main")
        #expect(data.pointsToday == 150)
        #expect(data.eventsTodayCount == 3)
        #expect(data.isValid == true)
    }

    @Test("Mock factory with custom values")
    func testMockFactoryWithCustomValues() throws {
        // When: Creating mock with custom values
        let data = CurrentExperiencePointsData.mock(experienceKey: "battle", pointsToday: 7500, eventsTodayCount: 200)

        // Then: Should have custom values
        #expect(data.experienceKey == "battle")
        #expect(data.pointsToday == 7500)
        #expect(data.eventsTodayCount == 200)
    }

    // MARK: - Codable Tests

    @Test("Encodes to snake_case keys")
    func testEncodesToSnakeCase() throws {
        // Given: XP data with all fields
        let data = CurrentExperiencePointsData.mock()

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = try encoder.encode(data)
        let json = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        // Then: Should use snake_case keys
        #expect(json["experience_id"] != nil)
        #expect(json["points_today"] != nil)
        #expect(json["events_today_count"] != nil)

        // And: Should not contain camelCase keys
        #expect(json["experienceId"] == nil)
        #expect(json["pointsToday"] == nil)
        #expect(json["eventsTodayCount"] == nil)
    }

    @Test("Decodes from snake_case keys")
    func testDecodesFromSnakeCase() throws {
        // Given: XP data
        let original = CurrentExperiencePointsData.mock(experienceKey: "battle", pointsToday: 3000)

        // When: Encoding then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CurrentExperiencePointsData.self, from: data)

        // Then: Should decode correctly
        #expect(decoded.experienceKey == "battle")
        #expect(decoded.pointsToday == 3000)
    }

    @Test("Roundtrip encoding preserves all data")
    func testRoundtripPreservesData() throws {
        // Given: Original XP data
        let original = CurrentExperiencePointsData.mock()

        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CurrentExperiencePointsData.self, from: data)

        // Then: Should preserve all data
        #expect(decoded == original)
    }

    @Test("Decodes with missing optional fields")
    func testDecodesWithMissingFields() throws {
        // Given: JSON with only required field
        let json = """
        {
            "experience_id": "minimal"
        }
        """
        let data = json.data(using: .utf8)!

        // When: Decoding
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CurrentExperiencePointsData.self, from: data)

        // Then: Should decode with nil optional fields
        #expect(decoded.experienceKey == "minimal")
        #expect(decoded.pointsToday == nil)
        #expect(decoded.eventsTodayCount == nil)
    }

    // MARK: - Validation Tests

    @Test("isValid true for valid data")
    func testIsValidTrue() throws {
        // Given: Valid XP data
        let data = CurrentExperiencePointsData.mock()

        // Then: Should be valid
        #expect(data.isValid == true)
    }

    @Test("isValid false when totalPoints negative")
    func testIsValidFalseNegativePoints() throws {
        // Given: Data with negative totalPoints
        let data = CurrentExperiencePointsData(experienceKey: "test", pointsToday: -100)

        // Then: Should be invalid
        #expect(data.isValid == false)
    }

    @Test("isValid false when totalEvents negative")
    func testIsValidFalseNegativeEvents() throws {
        // Given: Data with negative totalEvents
        let data = CurrentExperiencePointsData(experienceKey: "test", eventsTodayCount: -5)

        // Then: Should be invalid
        #expect(data.isValid == false)
    }

    // MARK: - Analytics Tests

    @Test("eventParameters includes all XP fields")
    func testEventParametersIncludesAllFields() throws {
        // Given: XP data with known values
        let data = CurrentExperiencePointsData.mock(experienceKey: "battle", pointsToday: 5000)

        // When: Getting event parameters
        let params = data.eventParameters

        // Then: Should include all fields with current_xp_ prefix
        #expect(params["current_xp_experience_id"] as? String == "battle")
        #expect(params["current_xp_points_today"] as? Int == 5000)
        #expect(params["current_xp_events_today_count"] != nil)
    }

    @Test("eventParameters prefixed with current_xp_")
    func testEventParametersPrefixed() throws {
        // Given: XP data with specific experienceId
        let data = CurrentExperiencePointsData.mock(experienceKey: "quest")

        // When: Getting event parameters
        let params = data.eventParameters

        // Then: Should prefix all keys with current_xp_
        #expect(params["current_xp_experience_id"] as? String == "quest")
        #expect(params["current_xp_points_today"] != nil)
        #expect(params["current_xp_events_today_count"] != nil)
    }

    // MARK: - Equatable Tests

    @Test("Same data makes instances equal")
    func testEquatableEqual() throws {
        // Given: Two instances with identical data
        let data1 = CurrentExperiencePointsData(
            experienceKey: "test",
            pointsToday: 5000,
            eventsTodayCount: 100
        )
        let data2 = CurrentExperiencePointsData(
            experienceKey: "test",
            pointsToday: 5000,
            eventsTodayCount: 100
        )

        // Then: Should be equal
        #expect(data1 == data2)
    }

    @Test("Different experienceId makes instances unequal")
    func testEquatableUnequalExperienceId() throws {
        // Given: Two instances differing only in experienceId
        let data1 = CurrentExperiencePointsData(experienceKey: "main")
        let data2 = CurrentExperiencePointsData(experienceKey: "battle")

        // Then: Should not be equal
        #expect(data1 != data2)
    }

    @Test("Different totalPoints makes instances unequal")
    func testEquatableUnequalTotalPoints() throws {
        // Given: Two instances differing only in totalPoints
        let data1 = CurrentExperiencePointsData(experienceKey: "test", pointsToday: 1000)
        let data2 = CurrentExperiencePointsData(experienceKey: "test", pointsToday: 2000)

        // Then: Should not be equal
        #expect(data1 != data2)
    }

    // MARK: - Stale Data Tests

    @Test("isDataStale returns true when updatedAt is nil")
    func testIsDataStaleWhenUpdatedAtNil() throws {
        // Given: Data with no updatedAt
        let data = CurrentExperiencePointsData(
            experienceKey: "test",
            pointsToday: 5000,
            dateUpdated: nil
        )

        // Then: Should be stale
        #expect(data.isDataStale == true)
    }

    @Test("isDataStale returns false when updated less than 1 hour ago")
    func testIsDataStaleWhenRecentlyUpdated() throws {
        // Given: Data updated 30 minutes ago
        let thirtyMinutesAgo = Date().addingTimeInterval(-30 * 60)
        let data = CurrentExperiencePointsData(
            experienceKey: "test",
            pointsToday: 5000,
            dateUpdated: thirtyMinutesAgo
        )

        // Then: Should not be stale
        #expect(data.isDataStale == false)
    }

    @Test("isDataStale returns true when updated over 1 hour ago")
    func testIsDataStaleWhenOldUpdate() throws {
        // Given: Data updated 2 hours ago
        let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)
        let data = CurrentExperiencePointsData(
            experienceKey: "test",
            pointsToday: 5000,
            dateUpdated: twoHoursAgo
        )

        // Then: Should be stale
        #expect(data.isDataStale == true)
    }

    @Test("isDataStale boundary: exactly 1 hour ago")
    func testIsDataStaleBoundary() throws {
        // Given: Data updated exactly 1 hour ago
        let oneHourAgo = Date().addingTimeInterval(-60 * 60)
        let data = CurrentExperiencePointsData(
            experienceKey: "test",
            pointsToday: 5000,
            dateUpdated: oneHourAgo
        )

        // Then: Should be stale (> 1 hour threshold)
        #expect(data.isDataStale == true)
    }

    @Test("isDataStale with fresh update")
    func testIsDataStaleWithCurrentUpdate() throws {
        // Given: Data updated now
        let data = CurrentExperiencePointsData(
            experienceKey: "test",
            pointsToday: 5000,
            dateUpdated: Date()
        )

        // Then: Should not be stale
        #expect(data.isDataStale == false)
    }

    @Test("isDataStale with 24 hour old data")
    func testIsDataStaleWith24HourOldData() throws {
        // Given: Data updated 24 hours ago
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        let data = CurrentExperiencePointsData(
            experienceKey: "test",
            pointsToday: 5000,
            dateUpdated: oneDayAgo
        )

        // Then: Should be stale
        #expect(data.isDataStale == true)
    }
}
