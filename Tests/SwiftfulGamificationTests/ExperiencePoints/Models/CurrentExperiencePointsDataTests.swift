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
            totalPoints: totalPoints,
            totalEvents: totalEvents,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        // Then: All properties should be set correctly
        #expect(data.experienceKey == experienceId)
        #expect(data.totalPoints == totalPoints)
        #expect(data.totalEvents == totalEvents)
        #expect(data.createdAt == createdAt)
        #expect(data.updatedAt == updatedAt)
    }

    @Test("Blank factory creates zero data")
    func testBlankFactoryCreatesZeroData() throws {
        // When: Creating blank data
        let data = CurrentExperiencePointsData.blank(experienceKey: "main")

        // Then: Should have zero values
        #expect(data.experienceKey == "main")
        #expect(data.totalPoints == 0)
        #expect(data.totalEvents == 0)
    }

    @Test("Mock factory creates valid data")
    func testMockFactoryCreatesValidData() throws {
        // When: Creating mock data
        let data = CurrentExperiencePointsData.mock()

        // Then: Should have default values
        #expect(data.experienceKey == "main")
        #expect(data.totalPoints == 1500)
        #expect(data.totalEvents == 25)
        #expect(data.isValid == true)
    }

    @Test("Mock factory with custom values")
    func testMockFactoryWithCustomValues() throws {
        // When: Creating mock with custom values
        let data = CurrentExperiencePointsData.mock(experienceKey: "battle", totalPoints: 7500, totalEvents: 200)

        // Then: Should have custom values
        #expect(data.experienceKey == "battle")
        #expect(data.totalPoints == 7500)
        #expect(data.totalEvents == 200)
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
        #expect(json["total_points"] != nil)
        #expect(json["total_events"] != nil)

        // And: Should not contain camelCase keys
        #expect(json["experienceId"] == nil)
        #expect(json["totalPoints"] == nil)
        #expect(json["totalEvents"] == nil)
    }

    @Test("Decodes from snake_case keys")
    func testDecodesFromSnakeCase() throws {
        // Given: XP data
        let original = CurrentExperiencePointsData.mock(experienceKey: "battle", totalPoints: 3000)

        // When: Encoding then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CurrentExperiencePointsData.self, from: data)

        // Then: Should decode correctly
        #expect(decoded.experienceKey == "battle")
        #expect(decoded.totalPoints == 3000)
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
        #expect(decoded.totalPoints == nil)
        #expect(decoded.totalEvents == nil)
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
        let data = CurrentExperiencePointsData(experienceKey: "test", totalPoints: -100)

        // Then: Should be invalid
        #expect(data.isValid == false)
    }

    @Test("isValid false when totalEvents negative")
    func testIsValidFalseNegativeEvents() throws {
        // Given: Data with negative totalEvents
        let data = CurrentExperiencePointsData(experienceKey: "test", totalEvents: -5)

        // Then: Should be invalid
        #expect(data.isValid == false)
    }

    // MARK: - Analytics Tests

    @Test("eventParameters includes all XP fields")
    func testEventParametersIncludesAllFields() throws {
        // Given: XP data with known values
        let data = CurrentExperiencePointsData.mock(experienceKey: "battle", totalPoints: 5000)

        // When: Getting event parameters
        let params = data.eventParameters

        // Then: Should include all fields with current_xp_ prefix
        #expect(params["current_xp_experience_id"] as? String == "battle")
        #expect(params["current_xp_total_points"] as? Int == 5000)
        #expect(params["current_xp_total_events"] != nil)
    }

    @Test("eventParameters prefixed with current_xp_")
    func testEventParametersPrefixed() throws {
        // Given: XP data with specific experienceId
        let data = CurrentExperiencePointsData.mock(experienceKey: "quest")

        // When: Getting event parameters
        let params = data.eventParameters

        // Then: Should prefix all keys with current_xp_
        #expect(params["current_xp_experience_id"] as? String == "quest")
        #expect(params["current_xp_total_points"] != nil)
        #expect(params["current_xp_total_events"] != nil)
    }

    // MARK: - Equatable Tests

    @Test("Same data makes instances equal")
    func testEquatableEqual() throws {
        // Given: Two instances with identical data
        let data1 = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 5000,
            totalEvents: 100
        )
        let data2 = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 5000,
            totalEvents: 100
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
        let data1 = CurrentExperiencePointsData(experienceKey: "test", totalPoints: 1000)
        let data2 = CurrentExperiencePointsData(experienceKey: "test", totalPoints: 2000)

        // Then: Should not be equal
        #expect(data1 != data2)
    }

    // MARK: - Stale Data Tests

    @Test("isDataStale returns true when updatedAt is nil")
    func testIsDataStaleWhenUpdatedAtNil() throws {
        // Given: Data with no updatedAt
        let data = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 5000,
            updatedAt: nil
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
            totalPoints: 5000,
            updatedAt: thirtyMinutesAgo
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
            totalPoints: 5000,
            updatedAt: twoHoursAgo
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
            totalPoints: 5000,
            updatedAt: oneHourAgo
        )

        // Then: Should be stale (> 1 hour threshold)
        #expect(data.isDataStale == true)
    }

    @Test("isDataStale with fresh update")
    func testIsDataStaleWithCurrentUpdate() throws {
        // Given: Data updated now
        let data = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 5000,
            updatedAt: Date()
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
            totalPoints: 5000,
            updatedAt: oneDayAgo
        )

        // Then: Should be stale
        #expect(data.isDataStale == true)
    }
}
