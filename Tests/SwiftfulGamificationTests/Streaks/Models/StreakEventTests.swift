//
//  StreakEventTests.swift
//  SwiftfulGamificationTests
//
//  Tests for StreakEvent model
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("StreakEvent Tests")
struct StreakEventTests {

    // MARK: - Initialization Tests

    @Test("Default init generates UUID and uses current date/timezone")
    func testDefaultInitialization() throws {
        // When: Creating event with default parameters
        let before = Date()
        let event = StreakEvent()
        let after = Date()

        // Then: Should generate UUID
        #expect(!event.id.isEmpty)
        #expect(UUID(uuidString: event.id) != nil) // Valid UUID format

        // And: Should use current timestamp
        #expect(event.timestamp >= before)
        #expect(event.timestamp <= after)

        // And: Should use current timezone
        #expect(event.timezone == TimeZone.current.identifier)

        // And: Should have empty metadata
        #expect(event.metadata.isEmpty)
    }

    @Test("Custom init uses provided values")
    func testCustomInitialization() throws {
        // Given: Custom values for all parameters
        let id = "custom-id-123"
        let timestamp = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
        let timezone = "America/New_York"
        let metadata: [String: GamificationDictionaryValue] = [
            "workout_type": "running",
            "distance": 5.5,
            "completed": true,
            "reps": 10
        ]

        // When: Creating event with custom parameters
        let event = StreakEvent(
            id: id,
            timestamp: timestamp,
            timezone: timezone,
            metadata: metadata
        )

        // Then: All properties should match provided values
        #expect(event.id == id)
        #expect(event.timestamp == timestamp)
        #expect(event.timezone == timezone)
        #expect(event.metadata.count == 4)
        #expect(event.metadata["workout_type"] == .string("running"))
        #expect(event.metadata["distance"] == .double(5.5))
        #expect(event.metadata["completed"] == .bool(true))
        #expect(event.metadata["reps"] == .int(10))
    }

    @Test("Mock factory creates valid event")
    func testMockFactoryValid() throws {
        // When: Creating a mock event
        let event = StreakEvent.mock()

        // Then: Should create valid event
        #expect(!event.id.isEmpty)
        #expect(UUID(uuidString: event.id) != nil)
        #expect(event.timezone == TimeZone.current.identifier)
        #expect(event.metadata["action"] == .string("test"))
        #expect(event.isValid == true)
    }

    @Test("Mock with date creates event at specific time")
    func testMockWithDate() throws {
        // Given: A specific date and timezone
        let specificDate = Date(timeIntervalSince1970: 1609459200) // 2021-01-01 00:00:00 UTC
        let timezone = "Europe/London"

        // When: Creating mock with specific date
        let event = StreakEvent.mock(date: specificDate, timezone: timezone)

        // Then: Should use provided date and timezone
        #expect(event.timestamp == specificDate)
        #expect(event.timezone == timezone)
        #expect(!event.id.isEmpty)
        #expect(event.metadata["action"] == .string("test"))
    }

    @Test("Mock with daysAgo creates event in past")
    func testMockWithDaysAgo() throws {
        // Given: A specific number of days ago
        let daysAgo = 5

        // When: Creating mock with daysAgo
        let event = StreakEvent.mock(daysAgo: daysAgo)

        // Then: Should create event 5 days in the past
        let expectedDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let timeDifference = abs(event.timestamp.timeIntervalSince(expectedDate))

        // Allow small time difference (< 1 second) due to execution time
        #expect(timeDifference < 1.0)
        #expect(event.timezone == TimeZone.current.identifier)
        #expect(!event.id.isEmpty)
    }

    // MARK: - Codable Tests

    @Test("Encodes to JSON with all fields")
    func testEncodesToJSON() throws {
        // Given: An event with known values
        let timestamp = Date(timeIntervalSince1970: 1609459200)
        let event = StreakEvent(
            id: "event-123",
            timestamp: timestamp,
            timezone: "America/Los_Angeles",
            metadata: ["type": "workout", "reps": 50]
        )

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then: Should encode all fields
        #expect(json["id"] as? String == "event-123")
        #expect(json["timestamp"] as? Double == timestamp.timeIntervalSinceReferenceDate)
        #expect(json["timezone"] as? String == "America/Los_Angeles")
        #expect(json["metadata"] != nil)
    }

    @Test("Decodes from JSON with all fields")
    func testDecodesFromJSON() throws {
        // Given: JSON with all event fields
        let timestamp = Date(timeIntervalSince1970: 1609459200)
        let event = StreakEvent(
            id: "event-456",
            timestamp: timestamp,
            timezone: "Asia/Tokyo",
            metadata: ["action": "complete", "score": 95]
        )

        // When: Encoding then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StreakEvent.self, from: data)

        // Then: Should decode all fields correctly
        #expect(decoded.id == "event-456")
        #expect(decoded.timestamp == timestamp)
        #expect(decoded.timezone == "Asia/Tokyo")
        #expect(decoded.metadata.count == 2)
        #expect(decoded.metadata["action"] == .string("complete"))
        #expect(decoded.metadata["score"] == .int(95))
    }

    @Test("Roundtrip preserves all data")
    func testRoundtripPreservesData() throws {
        // Given: Original event with complex metadata
        let original = StreakEvent(
            id: "roundtrip-test",
            timestamp: Date(timeIntervalSince1970: 1609459200),
            timezone: "Europe/Paris",
            metadata: [
                "type": "cardio",
                "duration": 45.5,
                "completed": true,
                "reps": 100
            ]
        )

        // When: Encoding and then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StreakEvent.self, from: data)

        // Then: Should preserve all data
        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.timestamp == original.timestamp)
        #expect(decoded.timezone == original.timezone)
        #expect(decoded.metadata == original.metadata)
    }

    @Test("Metadata encodes/decodes correctly")
    func testMetadataEncodingDecoding() throws {
        // Given: Event with various metadata types
        let original = StreakEvent(
            id: "metadata-test",
            timestamp: Date(),
            timezone: "UTC",
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
        let decoded = try decoder.decode(StreakEvent.self, from: data)

        // Then: All metadata types should be preserved
        #expect(decoded.metadata["string_val"] == .string("hello"))
        #expect(decoded.metadata["bool_val"] == .bool(false))
        #expect(decoded.metadata["int_val"] == .int(42))
        #expect(decoded.metadata["double_val"] == .double(3.14159))
    }

    // MARK: - Validation Tests

    @Test("isValid true for valid event")
    func testIsValidTrue() throws {
        // Given: A valid event (recent timestamp, valid timezone, valid metadata keys)
        let event = StreakEvent(
            id: "valid-id",
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            timezone: "America/New_York",
            metadata: ["valid_key": "value", "another_key_123": 42]
        )

        // Then: Should be valid
        #expect(event.isValid == true)
        #expect(event.isIdValid == true)
        #expect(event.isTimestampValid == true)
        #expect(event.isTimezoneValid == true)
        #expect(event.isMetadataValid == true)
    }

    @Test("isValid false when ID empty")
    func testIsValidFalseEmptyId() throws {
        // Given: Event with empty ID
        let event = StreakEvent(
            id: "",
            timestamp: Date(),
            timezone: "UTC",
            metadata: [:]
        )

        // Then: Should be invalid
        #expect(event.isValid == false)
        #expect(event.isIdValid == false)
    }

    @Test("isValid false when timestamp in future")
    func testIsValidFalseFutureTimestamp() throws {
        // Given: Event with future timestamp
        let futureDate = Date().addingTimeInterval(3600) // 1 hour in future
        let event = StreakEvent(
            id: "future-event",
            timestamp: futureDate,
            timezone: "UTC",
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
        let event = StreakEvent(
            id: "old-event",
            timestamp: oldDate,
            timezone: "UTC",
            metadata: [:]
        )

        // Then: Should be invalid
        #expect(event.isValid == false)
        #expect(event.isTimestampValid == false)
    }

    @Test("isValid false when timezone invalid")
    func testIsValidFalseInvalidTimezone() throws {
        // Given: Event with invalid timezone identifier
        let event = StreakEvent(
            id: "invalid-tz",
            timestamp: Date(),
            timezone: "Invalid/Timezone",
            metadata: [:]
        )

        // Then: Should be invalid
        #expect(event.isValid == false)
        #expect(event.isTimezoneValid == false)
    }

    @Test("isValid false when metadata keys contain special characters")
    func testIsValidFalseInvalidMetadataKeys() throws {
        // Given: Event with metadata keys containing special characters (not allowed in Firestore)
        let event = StreakEvent(
            id: "invalid-metadata",
            timestamp: Date(),
            timezone: "UTC",
            metadata: ["invalid-key": "value"] // Hyphen not allowed
        )

        // Then: Should be invalid
        #expect(event.isValid == false)
        #expect(event.isMetadataValid == false)
    }

    @Test("isValid true for valid timezone identifiers")
    func testIsValidTrueValidTimezones() throws {
        // Given: Various valid timezone identifiers
        let timezones = [
            "UTC",
            "America/New_York",
            "Europe/London",
            "Asia/Tokyo",
            "Australia/Sydney",
            "America/Los_Angeles",
            "Europe/Paris"
        ]

        // When/Then: All should be valid
        for tz in timezones {
            let event = StreakEvent(id: "test", timestamp: Date(), timezone: tz, metadata: [:])
            #expect(event.isTimezoneValid == true, "Expected \(tz) to be valid")
        }
    }

    // MARK: - Analytics Tests

    @Test("eventParameters includes all fields")
    func testEventParametersIncludesFields() throws {
        // Given: Event with known values
        let timestamp = Date(timeIntervalSince1970: 1609459200)
        let event = StreakEvent(
            id: "analytics-test",
            timestamp: timestamp,
            timezone: "America/Chicago",
            metadata: ["type": "workout"]
        )

        // When: Getting event parameters
        let params = event.eventParameters

        // Then: Should include all basic fields
        #expect(params["event_id"] as? String == "analytics-test")
        #expect(params["timestamp"] as? Double == timestamp.timeIntervalSince1970)
        #expect(params["timezone"] as? String == "America/Chicago")
        #expect(params["metadata_count"] as? Int == 1)
    }

    @Test("eventParameters converts metadata correctly")
    func testEventParametersMetadataConversion() throws {
        // Given: Event with various metadata types
        let event = StreakEvent(
            id: "metadata-analytics",
            timestamp: Date(),
            timezone: "UTC",
            metadata: [
                "workout_type": "cardio",
                "reps": 50,
                "completed": true,
                "distance": 5.5
            ]
        )

        // When: Getting event parameters
        let params = event.eventParameters

        // Then: Metadata should be prefixed with "metadata_" and converted to Any
        #expect(params["metadata_workout_type"] as? String == "cardio")
        #expect(params["metadata_reps"] as? Int == 50)
        #expect(params["metadata_completed"] as? Bool == true)
        #expect(params["metadata_distance"] as? Double == 5.5)
    }

    @Test("eventParameters includes metadata count")
    func testEventParametersMetadataCount() throws {
        // Given: Events with different metadata counts
        let emptyEvent = StreakEvent(id: "empty", timestamp: Date(), timezone: "UTC", metadata: [:])
        let multiEvent = StreakEvent(
            id: "multi",
            timestamp: Date(),
            timezone: "UTC",
            metadata: ["a": 1, "b": 2, "c": 3]
        )

        // When: Getting event parameters
        let emptyParams = emptyEvent.eventParameters
        let multiParams = multiEvent.eventParameters

        // Then: Should include correct metadata count
        #expect(emptyParams["metadata_count"] as? Int == 0)
        #expect(multiParams["metadata_count"] as? Int == 3)
    }

    // MARK: - Equatable Tests

    @Test("Same events are equal")
    func testEquatableEqual() throws {
        // Given: Two events with identical values
        let timestamp = Date(timeIntervalSince1970: 1609459200)
        let event1 = StreakEvent(
            id: "same-id",
            timestamp: timestamp,
            timezone: "America/Denver",
            metadata: ["key": "value"]
        )
        let event2 = StreakEvent(
            id: "same-id",
            timestamp: timestamp,
            timezone: "America/Denver",
            metadata: ["key": "value"]
        )

        // Then: Should be equal
        #expect(event1 == event2)
    }

    @Test("Different IDs make events unequal")
    func testEquatableUnequalId() throws {
        // Given: Two events differing only in ID
        let timestamp = Date()
        let event1 = StreakEvent(id: "id-1", timestamp: timestamp, timezone: "UTC", metadata: [:])
        let event2 = StreakEvent(id: "id-2", timestamp: timestamp, timezone: "UTC", metadata: [:])

        // Then: Should not be equal
        #expect(event1 != event2)
    }

    @Test("Different timestamps make events unequal")
    func testEquatableUnequalTimestamp() throws {
        // Given: Two events differing only in timestamp
        let timestamp1 = Date(timeIntervalSince1970: 1609459200)
        let timestamp2 = Date(timeIntervalSince1970: 1609462800)
        let event1 = StreakEvent(id: "same-id", timestamp: timestamp1, timezone: "UTC", metadata: [:])
        let event2 = StreakEvent(id: "same-id", timestamp: timestamp2, timezone: "UTC", metadata: [:])

        // Then: Should not be equal
        #expect(event1 != event2)
    }
}
