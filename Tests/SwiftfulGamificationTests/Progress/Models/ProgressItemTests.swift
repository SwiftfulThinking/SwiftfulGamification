//
//  ProgressItemTests.swift
//  SwiftfulGamificationTests
//
//  Tests for ProgressItem model
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("ProgressItem Tests")
struct ProgressItemTests {

    // MARK: - Initialization Tests

    @Test("Default init uses current date")
    func testDefaultInitialization() throws {
        // When: Creating item with default parameters
        let before = Date()
        let item = ProgressItem(id: "test_1", progressKey: "default", value: 0.5)
        let after = Date()

        // Then: Should use current dates
        #expect(item.id == "test_1")
        #expect(item.value == 0.5)
        #expect(item.dateCreated >= before)
        #expect(item.dateCreated <= after)
        #expect(item.dateModified >= before)
        #expect(item.dateModified <= after)
    }

    @Test("Custom init uses provided values")
    func testCustomInitialization() throws {
        // Given: Custom values for all parameters
        let id = "custom_progress_123"
        let value = 0.75
        let dateCreated = Date(timeIntervalSince1970: 1609459200)
        let dateModified = Date(timeIntervalSince1970: 1609545600)

        // When: Creating item with custom parameters
        let item = ProgressItem(
            id: id,
            progressKey: "default",
            value: value,
            dateCreated: dateCreated,
            dateModified: dateModified
        )

        // Then: All properties should match provided values
        #expect(item.id == id)
        #expect(item.value == value)
        #expect(item.dateCreated == dateCreated)
        #expect(item.dateModified == dateModified)
    }

    @Test("Mock factory creates valid item")
    func testMockFactoryValid() throws {
        // When: Creating a mock item
        let item = ProgressItem.mock()

        // Then: Should create valid item
        #expect(item.id == "progress_1")
        #expect(item.value == 0.5)
        #expect(item.isValid == true)
    }

    @Test("Mock factory accepts custom values")
    func testMockFactoryCustomValues() throws {
        // When: Creating mock with custom values
        let item = ProgressItem.mock(id: "custom_id", value: 0.9)

        // Then: Should use provided values
        #expect(item.id == "custom_id")
        #expect(item.value == 0.9)
        #expect(item.isValid == true)
    }

    // MARK: - Codable Tests

    @Test("Encodes to JSON with snake_case keys")
    func testEncodesToJSON() throws {
        // Given: An item with known values
        let dateCreated = Date(timeIntervalSince1970: 1609459200)
        let dateModified = Date(timeIntervalSince1970: 1609545600)
        let item = ProgressItem(
            id: "progress_123",
            progressKey: "default",
            value: 0.65,
            dateCreated: dateCreated,
            dateModified: dateModified
        )

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then: Should encode with snake_case keys
        #expect(json["id"] as? String == "progress_123")
        #expect(json["value"] as? Double == 0.65)
        #expect(json["date_created"] as? Double == dateCreated.timeIntervalSinceReferenceDate)
        #expect(json["date_modified"] as? Double == dateModified.timeIntervalSinceReferenceDate)
    }

    @Test("Decodes from JSON with snake_case keys")
    func testDecodesFromJSON() throws {
        // Given: JSON with snake_case keys
        let item = ProgressItem(
            id: "progress_456",
            progressKey: "default",
            value: 0.3,
            dateCreated: Date(timeIntervalSince1970: 1609459200),
            dateModified: Date(timeIntervalSince1970: 1609545600)
        )

        // When: Encoding then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(item)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProgressItem.self, from: data)

        // Then: Should decode all fields correctly
        #expect(decoded.id == item.id)
        #expect(decoded.value == item.value)
        #expect(decoded.dateCreated == item.dateCreated)
        #expect(decoded.dateModified == item.dateModified)
    }

    @Test("Roundtrip preserves all data")
    func testRoundtripPreservesData() throws {
        // Given: Original item
        let original = ProgressItem(
            id: "roundtrip_test",
            progressKey: "default",
            value: 0.999,
            dateCreated: Date(timeIntervalSince1970: 1609459200),
            dateModified: Date(timeIntervalSince1970: 1609545600)
        )

        // When: Encoding and then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProgressItem.self, from: data)

        // Then: Should preserve all data
        #expect(decoded.id == original.id)
        #expect(decoded.value == original.value)
        #expect(decoded.dateCreated == original.dateCreated)
        #expect(decoded.dateModified == original.dateModified)
    }

    // MARK: - Validation Tests

    @Test("isValid true for valid item")
    func testIsValidTrue() throws {
        // Given: A valid item
        let item = ProgressItem(id: "valid_id", progressKey: "default", value: 0.5)

        // Then: Should be valid
        #expect(item.isValid == true)
        #expect(item.isIdValid == true)
        #expect(item.isValueValid == true)
    }

    @Test("isValid false when ID empty")
    func testIsValidFalseEmptyId() throws {
        // Given: Item with empty ID
        let item = ProgressItem(id: "", progressKey: "default", value: 0.5)

        // Then: Should be invalid
        #expect(item.isValid == false)
        #expect(item.isIdValid == false)
    }

    @Test("isValid false when value negative")
    func testIsValidFalseNegativeValue() throws {
        // Given: Item with negative value
        let item = ProgressItem(id: "test", progressKey: "default", value: -0.1)

        // Then: Should be invalid
        #expect(item.isValid == false)
        #expect(item.isValueValid == false)
    }

    @Test("isValid false when value greater than 1")
    func testIsValidFalseValueTooLarge() throws {
        // Given: Item with value > 1.0
        let item = ProgressItem(id: "test", progressKey: "default", value: 1.1)

        // Then: Should be invalid
        #expect(item.isValid == false)
        #expect(item.isValueValid == false)
    }

    @Test("isValid true for boundary values")
    func testIsValidTrueBoundaryValues() throws {
        // Given: Items with boundary values
        let minItem = ProgressItem(id: "min", progressKey: "default", value: 0.0)
        let maxItem = ProgressItem(id: "max", progressKey: "default", value: 1.0)

        // Then: Should be valid
        #expect(minItem.isValid == true)
        #expect(minItem.isValueValid == true)
        #expect(maxItem.isValid == true)
        #expect(maxItem.isValueValid == true)
    }

    // MARK: - Analytics Tests

    @Test("eventParameters includes all fields")
    func testEventParametersIncludesFields() throws {
        // Given: Item with known values
        let dateCreated = Date(timeIntervalSince1970: 1609459200)
        let dateModified = Date(timeIntervalSince1970: 1609545600)
        let item = ProgressItem(
            id: "analytics_test",
            progressKey: "default",
            value: 0.85,
            dateCreated: dateCreated,
            dateModified: dateModified
        )

        // When: Getting event parameters
        let params = item.eventParameters

        // Then: Should include all fields with progress_ prefix
        #expect(params["progress_id"] as? String == "analytics_test")
        #expect(params["progress_value"] as? Double == 0.85)
        #expect(params["progress_date_created"] as? Double == dateCreated.timeIntervalSince1970)
        #expect(params["progress_date_modified"] as? Double == dateModified.timeIntervalSince1970)
    }

    @Test("eventParameters has correct types")
    func testEventParametersTypes() throws {
        // Given: A progress item
        let item = ProgressItem.mock()

        // When: Getting event parameters
        let params = item.eventParameters

        // Then: Types should match
        #expect(params["progress_id"] is String)
        #expect(params["progress_value"] is Double)
        #expect(params["progress_date_created"] is Double)
        #expect(params["progress_date_modified"] is Double)
    }

    // MARK: - Metadata Tests

    @Test("Metadata validates valid keys")
    func testMetadataValidatesValidKeys() throws {
        // Given: Item with valid metadata keys
        let item = ProgressItem(
            id: "test",
            progressKey: "default",
            value: 0.5,
            dateCreated: Date(),
            dateModified: Date(),
            metadata: [
                "valid_key": .string("value"),
                "key123": .int(42),
                "KEY_NAME": .double(3.14),
                "some_long_key_123": .bool(true)
            ]
        )

        // Then: Should be valid
        #expect(item.isValid == true)
        #expect(item.isMetadataValid == true)
    }

    @Test("Metadata invalidates keys with special characters")
    func testMetadataInvalidatesSpecialCharacters() throws {
        // Given: Item with invalid metadata key (contains hyphen)
        let item = ProgressItem(
            id: "test",
            progressKey: "default",
            value: 0.5,
            dateCreated: Date(),
            dateModified: Date(),
            metadata: ["invalid-key": .string("value")]
        )

        // Then: Should be invalid
        #expect(item.isValid == false)
        #expect(item.isMetadataValid == false)
    }

    @Test("Metadata invalidates keys with spaces")
    func testMetadataInvalidatesSpaces() throws {
        // Given: Item with invalid metadata key (contains space)
        let item = ProgressItem(
            id: "test",
            progressKey: "default",
            value: 0.5,
            dateCreated: Date(),
            dateModified: Date(),
            metadata: ["invalid key": .string("value")]
        )

        // Then: Should be invalid
        #expect(item.isValid == false)
        #expect(item.isMetadataValid == false)
    }

    @Test("Metadata encodes and decodes correctly")
    func testMetadataEncodesDecodes() throws {
        // Given: Item with various metadata types
        let original = ProgressItem(
            id: "metadata_test",
            progressKey: "default",
            value: 0.75,
            dateCreated: Date(timeIntervalSince1970: 1609459200),
            dateModified: Date(timeIntervalSince1970: 1609545600),
            metadata: [
                "string_key": .string("test_value"),
                "int_key": .int(42),
                "double_key": .double(3.14),
                "bool_key": .bool(true)
            ]
        )

        // When: Encoding then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ProgressItem.self, from: data)

        // Then: Should preserve all metadata
        #expect(decoded.metadata["string_key"] == .string("test_value"))
        #expect(decoded.metadata["int_key"] == .int(42))
        #expect(decoded.metadata["double_key"] == .double(3.14))
        #expect(decoded.metadata["bool_key"] == .bool(true))
    }

    @Test("Metadata appears in eventParameters")
    func testMetadataInEventParameters() throws {
        // Given: Item with metadata
        let item = ProgressItem(
            id: "test",
            progressKey: "default",
            value: 0.5,
            dateCreated: Date(),
            dateModified: Date(),
            metadata: [
                "world": .string("world_1"),
                "level": .int(5),
                "completed": .bool(true)
            ]
        )

        // When: Getting event parameters
        let params = item.eventParameters

        // Then: Should include metadata with progress_metadata_ prefix
        #expect(params["progress_metadata_world"] as? String == "world_1")
        #expect(params["progress_metadata_level"] as? Int == 5)
        #expect(params["progress_metadata_completed"] as? Bool == true)
    }

    @Test("Empty metadata is valid")
    func testEmptyMetadataIsValid() throws {
        // Given: Item with empty metadata
        let item = ProgressItem(
            id: "test",
            progressKey: "default",
            value: 0.5,
            dateCreated: Date(),
            dateModified: Date(),
            metadata: [:]
        )

        // Then: Should be valid
        #expect(item.isValid == true)
        #expect(item.isMetadataValid == true)
    }

    // MARK: - ProgressKey and CompositeId Tests

    @Test("CompositeId generated correctly from progressKey and id")
    func testCompositeIdGeneration() throws {
        // Given: Item with known progressKey and id
        let item = ProgressItem(
            id: "item_123",
            progressKey: "world_1",
            value: 0.5
        )

        // Then: CompositeId should be progressKey_id
        #expect(item.compositeId == "world_1_item_123")
    }

    @Test("Items with same id but different progressKey have different compositeId")
    func testDifferentProgressKeysDifferentCompositeId() throws {
        // Given: Items with same id but different progressKeys
        let item1 = ProgressItem(id: "level_1", progressKey: "world_1", value: 0.5)
        let item2 = ProgressItem(id: "level_1", progressKey: "world_2", value: 0.8)

        // Then: Should have different composite IDs
        #expect(item1.compositeId == "world_1_level_1")
        #expect(item2.compositeId == "world_2_level_1")
        #expect(item1.compositeId != item2.compositeId)
    }

    @Test("ProgressKey is stored separately from id")
    func testProgressKeyStoredSeparately() throws {
        // Given: Item with specific progressKey
        let item = ProgressItem(
            id: "test_id",
            progressKey: "custom_key",
            value: 0.75
        )

        // Then: Both should be accessible independently
        #expect(item.id == "test_id")
        #expect(item.progressKey == "custom_key")
    }
}
