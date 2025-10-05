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
        let item = ProgressItem(id: "test_1", value: 0.5)
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
        let item = ProgressItem(id: "valid_id", value: 0.5)

        // Then: Should be valid
        #expect(item.isValid == true)
        #expect(item.isIdValid == true)
        #expect(item.isValueValid == true)
    }

    @Test("isValid false when ID empty")
    func testIsValidFalseEmptyId() throws {
        // Given: Item with empty ID
        let item = ProgressItem(id: "", value: 0.5)

        // Then: Should be invalid
        #expect(item.isValid == false)
        #expect(item.isIdValid == false)
    }

    @Test("isValid false when value negative")
    func testIsValidFalseNegativeValue() throws {
        // Given: Item with negative value
        let item = ProgressItem(id: "test", value: -0.1)

        // Then: Should be invalid
        #expect(item.isValid == false)
        #expect(item.isValueValid == false)
    }

    @Test("isValid false when value greater than 1")
    func testIsValidFalseValueTooLarge() throws {
        // Given: Item with value > 1.0
        let item = ProgressItem(id: "test", value: 1.1)

        // Then: Should be invalid
        #expect(item.isValid == false)
        #expect(item.isValueValid == false)
    }

    @Test("isValid true for boundary values")
    func testIsValidTrueBoundaryValues() throws {
        // Given: Items with boundary values
        let minItem = ProgressItem(id: "min", value: 0.0)
        let maxItem = ProgressItem(id: "max", value: 1.0)

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
}
