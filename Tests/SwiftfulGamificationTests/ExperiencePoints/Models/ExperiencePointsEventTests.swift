//
//  ExperiencePointsEventTests.swift
//  SwiftfulGamificationTests
//
//  Tests for ExperiencePointsEvent model
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("ExperiencePointsEvent Tests")
struct ExperiencePointsEventTests {

    // MARK: - Initialization Tests

    @Test("Default init generates UUID and uses current date")
    func testDefaultInitialization() throws {
        // When: Creating event with default parameters
        let before = Date()
        let event = ExperiencePointsEvent(experienceId: "main", points: 100)
        let after = Date()

        // Then: Should generate UUID
        #expect(!event.id.isEmpty)
        #expect(UUID(uuidString: event.id) != nil) // Valid UUID format

        // And: Should use current timestamp
        #expect(event.timestamp >= before)
        #expect(event.timestamp <= after)

        // And: Should have empty metadata
        #expect(event.metadata.isEmpty)
    }

    @Test("Custom init uses provided values")
    func testCustomInitialization() throws {
        // Given: Custom values for all parameters
        let id = "custom-xp-123"
        let experienceId = "battle"
        let timestamp = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
        let points = 250
        let metadata: [String: GamificationDictionaryValue] = [
            "source": "quest",
            "difficulty": 5.5,
            "completed": true,
            "bonus": 50
        ]

        // When: Creating event with custom parameters
        let event = ExperiencePointsEvent(
            id: id,
            experienceId: experienceId,
            timestamp: timestamp,
            points: points,
            metadata: metadata
        )

        // Then: All properties should match provided values
        #expect(event.id == id)
        #expect(event.experienceId == experienceId)
        #expect(event.timestamp == timestamp)
        #expect(event.points == points)
        #expect(event.metadata.count == 4)
        #expect(event.metadata["source"] == .string("quest"))
        #expect(event.metadata["difficulty"] == .double(5.5))
        #expect(event.metadata["completed"] == .bool(true))
        #expect(event.metadata["bonus"] == .int(50))
    }

    @Test("Mock factory creates valid event")
    func testMockFactoryValid() throws {
        // When: Creating a mock event
        let event = ExperiencePointsEvent.mock()

        // Then: Should create valid event
        #expect(!event.id.isEmpty)
        #expect(UUID(uuidString: event.id) != nil)
        #expect(event.experienceId == "main")
        #expect(event.points == 100)
        #expect(event.metadata["source"] == .string("test"))
        #expect(event.isValid == true)
    }

    @Test("Mock with date creates event at specific time")
    func testMockWithDate() throws {
        // Given: A specific date
        let specificDate = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
        let experienceId = "quest"

        // When: Creating mock with specific date
        let event = ExperiencePointsEvent.mock(date: specificDate, experienceId: experienceId, points: 500)

        // Then: Should use provided date
        #expect(event.timestamp == specificDate)
        #expect(event.experienceId == experienceId)
        #expect(event.points == 500)
        #expect(!event.id.isEmpty)
        #expect(event.metadata["source"] == .string("test"))
    }

    @Test("Mock with daysAgo creates event in past")
    func testMockWithDaysAgo() throws {
        // Given: A specific number of days ago
        let daysAgo = 5

        // When: Creating mock with daysAgo
        let event = ExperiencePointsEvent.mock(daysAgo: daysAgo, experienceId: "main", points: 75)

        // Then: Should create event 5 days in the past
        let expectedDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let timeDifference = abs(event.timestamp.timeIntervalSince(expectedDate))

        // Allow small time difference (< 1 second) due to execution time
        #expect(timeDifference < 1.0)
        #expect(event.experienceId == "main")
        #expect(event.points == 75)
        #expect(!event.id.isEmpty)
    }

    // MARK: - Codable Tests

    @Test("Encodes to JSON with all fields")
    func testEncodesToJSON() throws {
        // Given: An event with known values
        let timestamp = Date(timeIntervalSince1970: 1609459200)
        let event = ExperiencePointsEvent(
            id: "xp-123",
            experienceId: "main",
            timestamp: timestamp,
            points: 300,
            metadata: ["type": "bonus", "multiplier": 2]
        )

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then: Should encode all fields
        #expect(json["id"] as? String == "xp-123")
        #expect(json["experience_id"] as? String == "main")
        #expect(json["timestamp"] as? Double == timestamp.timeIntervalSinceReferenceDate)
        #expect(json["points"] as? Int == 300)
        #expect(json["metadata"] != nil)
    }

    @Test("Decodes from JSON with all fields")
    func testDecodesFromJSON() throws {
        // Given: JSON with all event fields
        let timestamp = Date(timeIntervalSince1970: 1609459200)
        let event = ExperiencePointsEvent(
            id: "xp-456",
            experienceId: "battle",
            timestamp: timestamp,
            points: 150,
            metadata: ["action": "complete", "score": 95]
        )

        // When: Encoding then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ExperiencePointsEvent.self, from: data)

        // Then: Should decode all fields correctly
        #expect(decoded.id == "xp-456")
        #expect(decoded.experienceId == "battle")
        #expect(decoded.timestamp == timestamp)
        #expect(decoded.points == 150)
        #expect(decoded.metadata.count == 2)
        #expect(decoded.metadata["action"] == .string("complete"))
        #expect(decoded.metadata["score"] == .int(95))
    }

    @Test("Roundtrip preserves all data")
    func testRoundtripPreservesData() throws {
        // Given: Original event with complex metadata
        let original = ExperiencePointsEvent(
            id: "roundtrip-test",
            experienceId: "quest",
            timestamp: Date(timeIntervalSince1970: 1609459200),
            points: 500,
            metadata: [
                "type": "epic",
                "duration": 45.5,
                "completed": true,
                "enemies": 25
            ]
        )

        // When: Encoding and then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ExperiencePointsEvent.self, from: data)

        // Then: Should preserve all data
        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.experienceId == original.experienceId)
        #expect(decoded.timestamp == original.timestamp)
        #expect(decoded.points == original.points)
        #expect(decoded.metadata == original.metadata)
    }

    @Test("Metadata encodes/decodes correctly")
    func testMetadataEncodingDecoding() throws {
        // Given: Event with various metadata types
        let original = ExperiencePointsEvent(
            id: "metadata-test",
            experienceId: "main",
            timestamp: Date(),
            points: 200,
            metadata: [
                "string_val": "hello",
                "bool_val": false,
                "int_val": 42,
                "double_val": 3.14159
            ]
        )

        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ExperiencePointsEvent.self, from: data)

        // Then: All metadata types should be preserved
        #expect(decoded.metadata["string_val"] == .string("hello"))
        #expect(decoded.metadata["bool_val"] == .bool(false))
        #expect(decoded.metadata["int_val"] == .int(42))
        #expect(decoded.metadata["double_val"] == .double(3.14159))
    }

    // MARK: - Validation Tests

    @Test("isValid true for valid event")
    func testIsValidTrue() throws {
        // Given: A valid event (recent timestamp, valid metadata keys, positive points)
        let event = ExperiencePointsEvent(
            id: "valid-id",
            experienceId: "main",
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            points: 100,
            metadata: ["valid_key": "value", "another_key_123": 42]
        )

        // Then: Should be valid
        #expect(event.isValid == true)
        #expect(event.isIdValid == true)
        #expect(event.isTimestampValid == true)
        #expect(event.isMetadataValid == true)
        #expect(event.isPointsValid == true)
    }

    @Test("isValid false when ID empty")
    func testIsValidFalseEmptyId() throws {
        // Given: Event with empty ID
        let event = ExperiencePointsEvent(
            id: "",
            experienceId: "main",
            timestamp: Date(),
            points: 100,
            metadata: [:]
        )

        // Then: Should be invalid
        #expect(event.isValid == false)
        #expect(event.isIdValid == false)
    }

    @Test("isValid false when points negative")
    func testIsValidFalseNegativePoints() throws {
        // Given: Event with negative points
        let event = ExperiencePointsEvent(
            id: "test",
            experienceId: "main",
            timestamp: Date(),
            points: -50,
            metadata: [:]
        )

        // Then: Should be invalid
        #expect(event.isValid == false)
        #expect(event.isPointsValid == false)
    }

    @Test("isValid true when points zero")
    func testIsValidTrueZeroPoints() throws {
        // Given: Event with zero points
        let event = ExperiencePointsEvent(
            id: "test",
            experienceId: "main",
            timestamp: Date(),
            points: 0,
            metadata: [:]
        )

        // Then: Should be valid (zero is allowed)
        #expect(event.isValid == true)
        #expect(event.isPointsValid == true)
    }

    @Test("isValid false when timestamp in future")
    func testIsValidFalseFutureTimestamp() throws {
        // Given: Event with future timestamp
        let futureDate = Date().addingTimeInterval(3600) // 1 hour in future
        let event = ExperiencePointsEvent(
            id: "future-event",
            experienceId: "main",
            timestamp: futureDate,
            points: 100,
            metadata: [:]
        )

        // Then: Should be invalid
        #expect(event.isValid == false)
        #expect(event.isTimestampValid == false)
    }

    @Test("isValid false when timestamp older than 1 year")
    func testIsValidFalseOldTimestamp() throws {
        // Given: Event with timestamp older than 1 year
        let oldDate = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let event = ExperiencePointsEvent(
            id: "old-event",
            experienceId: "main",
            timestamp: oldDate,
            points: 100,
            metadata: [:]
        )

        // Then: Should be invalid
        #expect(event.isValid == false)
        #expect(event.isTimestampValid == false)
    }

    @Test("isValid false when metadata keys contain special characters")
    func testIsValidFalseInvalidMetadataKeys() throws {
        // Given: Event with metadata keys containing special characters (not allowed in Firestore)
        let event = ExperiencePointsEvent(
            id: "invalid-metadata",
            experienceId: "main",
            timestamp: Date(),
            points: 100,
            metadata: ["invalid-key": "value"] // Hyphen not allowed
        )

        // Then: Should be invalid
        #expect(event.isValid == false)
        #expect(event.isMetadataValid == false)
    }

    // MARK: - Analytics Tests

    @Test("eventParameters includes all fields")
    func testEventParametersIncludesFields() throws {
        // Given: Event with known values
        let timestamp = Date(timeIntervalSince1970: 1609459200)
        let event = ExperiencePointsEvent(
            id: "analytics-test",
            experienceId: "battle",
            timestamp: timestamp,
            points: 500,
            metadata: ["type": "boss"]
        )

        // When: Getting event parameters
        let params = event.eventParameters

        // Then: Should include all basic fields with xp_event_ prefix
        #expect(params["xp_event_id"] as? String == "analytics-test")
        #expect(params["xp_event_experience_id"] as? String == "battle")
        #expect(params["xp_event_timestamp"] as? Double == timestamp.timeIntervalSince1970)
        #expect(params["xp_event_points"] as? Int == 500)
        #expect(params["xp_event_metadata_count"] as? Int == 1)
    }

    @Test("eventParameters converts metadata correctly")
    func testEventParametersMetadataConversion() throws {
        // Given: Event with various metadata types
        let event = ExperiencePointsEvent(
            id: "metadata-analytics",
            experienceId: "quest",
            timestamp: Date(),
            points: 250,
            metadata: [
                "quest_type": "epic",
                "level": 50,
                "completed": true,
                "duration": 120.5
            ]
        )

        // When: Getting event parameters
        let params = event.eventParameters

        // Then: Metadata should be prefixed with "xp_event_metadata_" and converted to Any
        #expect(params["xp_event_metadata_quest_type"] as? String == "epic")
        #expect(params["xp_event_metadata_level"] as? Int == 50)
        #expect(params["xp_event_metadata_completed"] as? Bool == true)
        #expect(params["xp_event_metadata_duration"] as? Double == 120.5)
    }

    @Test("eventParameters includes metadata count")
    func testEventParametersMetadataCount() throws {
        // Given: Events with different metadata counts
        let emptyEvent = ExperiencePointsEvent(id: "empty", experienceId: "main", timestamp: Date(), points: 50, metadata: [:])
        let multiEvent = ExperiencePointsEvent(
            id: "multi",
            experienceId: "main",
            timestamp: Date(),
            points: 100,
            metadata: ["a": 1, "b": 2, "c": 3]
        )

        // When: Getting event parameters
        let emptyParams = emptyEvent.eventParameters
        let multiParams = multiEvent.eventParameters

        // Then: Should include correct metadata count with xp_event_ prefix
        #expect(emptyParams["xp_event_metadata_count"] as? Int == 0)
        #expect(multiParams["xp_event_metadata_count"] as? Int == 3)
    }

    // MARK: - Equatable Tests

    @Test("Same events are equal")
    func testEquatableEqual() throws {
        // Given: Two events with identical values
        let timestamp = Date(timeIntervalSince1970: 1609459200)
        let event1 = ExperiencePointsEvent(
            id: "same-id",
            experienceId: "main",
            timestamp: timestamp,
            points: 100,
            metadata: ["key": "value"]
        )
        let event2 = ExperiencePointsEvent(
            id: "same-id",
            experienceId: "main",
            timestamp: timestamp,
            points: 100,
            metadata: ["key": "value"]
        )

        // Then: Should be equal
        #expect(event1 == event2)
    }

    @Test("Different IDs make events unequal")
    func testEquatableUnequalId() throws {
        // Given: Two events differing only in ID
        let timestamp = Date()
        let event1 = ExperiencePointsEvent(id: "id-1", experienceId: "main", timestamp: timestamp, points: 100, metadata: [:])
        let event2 = ExperiencePointsEvent(id: "id-2", experienceId: "main", timestamp: timestamp, points: 100, metadata: [:])

        // Then: Should not be equal
        #expect(event1 != event2)
    }

    @Test("Different points make events unequal")
    func testEquatableUnequalPoints() throws {
        // Given: Two events differing only in points
        let timestamp = Date()
        let event1 = ExperiencePointsEvent(id: "same-id", experienceId: "main", timestamp: timestamp, points: 100, metadata: [:])
        let event2 = ExperiencePointsEvent(id: "same-id", experienceId: "main", timestamp: timestamp, points: 250, metadata: [:])

        // Then: Should not be equal
        #expect(event1 != event2)
    }

    @Test("Different timestamps make events unequal")
    func testEquatableUnequalTimestamp() throws {
        // Given: Two events differing only in timestamp
        let timestamp1 = Date(timeIntervalSince1970: 1609459200)
        let timestamp2 = Date(timeIntervalSince1970: 1609462800)
        let event1 = ExperiencePointsEvent(id: "same-id", experienceId: "main", timestamp: timestamp1, points: 100, metadata: [:])
        let event2 = ExperiencePointsEvent(id: "same-id", experienceId: "main", timestamp: timestamp2, points: 100, metadata: [:])

        // Then: Should not be equal
        #expect(event1 != event2)
    }
}
