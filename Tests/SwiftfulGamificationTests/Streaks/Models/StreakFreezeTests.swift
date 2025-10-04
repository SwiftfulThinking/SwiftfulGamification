//
//  StreakFreezeTests.swift
//  SwiftfulGamificationTests
//
//  Tests for StreakFreeze model
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("StreakFreeze Tests")
struct StreakFreezeTests {

    // MARK: - Initialization Tests

    @Test("Init with required fields creates valid freeze")
    func testInitWithRequiredFields() throws {
        // Given: Required fields for a freeze
        let id = "freeze-123"
        let streakId = "workout"

        // When: Creating freeze with required fields only
        let freeze = StreakFreeze(id: id, streakId: streakId)

        // Then: Should create valid freeze with nil optional fields
        #expect(freeze.id == id)
        #expect(freeze.streakId == streakId)
        #expect(freeze.earnedDate == nil)
        #expect(freeze.usedDate == nil)
        #expect(freeze.expiresAt == nil)
    }

    @Test("Mock factory creates valid freeze")
    func testMockFactoryValid() throws {
        // When: Creating mock freeze
        let freeze = StreakFreeze.mock()

        // Then: Should create valid freeze with default values
        #expect(!freeze.id.isEmpty)
        #expect(UUID(uuidString: freeze.id) != nil)
        #expect(freeze.streakId == "workout")
        #expect(freeze.earnedDate != nil)
        #expect(freeze.usedDate == nil)
        #expect(freeze.expiresAt == nil)
        #expect(freeze.isValid == true)
    }

    @Test("Mock unused creates available freeze")
    func testMockUnusedCreatesAvailable() throws {
        // When: Creating mockUnused freeze
        let freeze = StreakFreeze.mockUnused()

        // Then: Should be available (not used, not expired)
        #expect(freeze.isUsed == false)
        #expect(freeze.isExpired == false)
        #expect(freeze.isAvailable == true)
        #expect(freeze.usedDate == nil)
        #expect(freeze.earnedDate != nil)
    }

    @Test("Mock used creates consumed freeze")
    func testMockUsedCreatesConsumed() throws {
        // When: Creating mockUsed freeze
        let freeze = StreakFreeze.mockUsed()

        // Then: Should be used (not available)
        #expect(freeze.isUsed == true)
        #expect(freeze.isAvailable == false)
        #expect(freeze.usedDate != nil)
        #expect(freeze.earnedDate != nil)

        // And: usedDate should be after earnedDate
        #expect(freeze.usedDate! >= freeze.earnedDate!)
    }

    @Test("Mock expired creates expired freeze")
    func testMockExpiredCreatesExpired() throws {
        // When: Creating mockExpired freeze
        let freeze = StreakFreeze.mockExpired()

        // Then: Should be expired (not available)
        #expect(freeze.isExpired == true)
        #expect(freeze.isAvailable == false)
        #expect(freeze.isUsed == false) // Not used, just expired
        #expect(freeze.expiresAt != nil)
        #expect(freeze.earnedDate != nil)

        // And: expiresAt should be in the past
        #expect(freeze.expiresAt! < Date())
    }

    // MARK: - Codable Tests

    @Test("Encodes to snake_case keys")
    func testEncodesToSnakeCase() throws {
        // Given: A freeze with all fields
        let earnedDate = Date(timeIntervalSince1970: 1609459200)
        let usedDate = Date(timeIntervalSince1970: 1609545600)
        let expiresAt = Date(timeIntervalSince1970: 1612137600)
        let freeze = StreakFreeze(
            id: "freeze-123",
            streakId: "meditation",
            earnedDate: earnedDate,
            usedDate: usedDate,
            expiresAt: expiresAt
        )

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(freeze)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then: Should use snake_case keys
        #expect(json["id"] as? String == "freeze-123")
        #expect(json["streak_id"] as? String == "meditation")
        #expect(json["earned_date"] != nil)
        #expect(json["used_date"] != nil)
        #expect(json["expires_at"] != nil)

        // And: Should not contain camelCase keys
        #expect(json["streakId"] == nil)
        #expect(json["userId"] == nil)
        #expect(json["earnedDate"] == nil)
        #expect(json["usedDate"] == nil)
        #expect(json["expiresAt"] == nil)
    }

    @Test("Decodes from snake_case keys")
    func testDecodesFromSnakeCase() throws {
        // Given: A freeze
        let earnedDate = Date(timeIntervalSince1970: 1609459200)
        let freeze = StreakFreeze(
            id: "freeze-789",
            streakId: "reading",
            earnedDate: earnedDate,
            usedDate: nil,
            expiresAt: nil
        )

        // When: Encoding then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(freeze)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StreakFreeze.self, from: data)

        // Then: Should decode all properties correctly
        #expect(decoded.id == "freeze-789")
        #expect(decoded.streakId == "reading")
        #expect(decoded.earnedDate == earnedDate)
        #expect(decoded.usedDate == nil)
        #expect(decoded.expiresAt == nil)
    }

    @Test("Roundtrip preserves all data")
    func testRoundtripPreservesData() throws {
        // Given: Original freeze with all fields
        let original = StreakFreeze(
            id: "roundtrip-test",
            streakId: "journaling",
            earnedDate: Date(timeIntervalSince1970: 1609459200),
            usedDate: Date(timeIntervalSince1970: 1609545600),
            expiresAt: Date(timeIntervalSince1970: 1612137600)
        )

        // When: Encoding and then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StreakFreeze.self, from: data)

        // Then: Should preserve all data
        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.streakId == original.streakId)
        #expect(decoded.earnedDate == original.earnedDate)
        #expect(decoded.usedDate == original.usedDate)
        #expect(decoded.expiresAt == original.expiresAt)
    }

    // MARK: - Computed Property Tests

    @Test("isUsed true when usedDate present")
    func testIsUsedTrue() throws {
        // Given: Freeze with usedDate set
        let freeze = StreakFreeze(
            id: "used-freeze",
            streakId: "workout",
            usedDate: Date()
        )

        // Then: Should be marked as used
        #expect(freeze.isUsed == true)
    }

    @Test("isUsed false when usedDate nil")
    func testIsUsedFalse() throws {
        // Given: Freeze with no usedDate
        let freeze = StreakFreeze(
            id: "unused-freeze",
            streakId: "workout",
            usedDate: nil
        )

        // Then: Should not be marked as used
        #expect(freeze.isUsed == false)
    }

    @Test("isExpired false when expiresAt nil")
    func testIsExpiredFalseNoExpiry() throws {
        // Given: Freeze with no expiration date (never expires)
        let freeze = StreakFreeze(
            id: "no-expiry",
            streakId: "workout",
            expiresAt: nil
        )

        // Then: Should not be expired
        #expect(freeze.isExpired == false)
    }

    @Test("isExpired true when expiresAt in past")
    func testIsExpiredTrue() throws {
        // Given: Freeze with expiration in the past
        let pastDate = Date().addingTimeInterval(-86400) // 1 day ago
        let freeze = StreakFreeze(
            id: "expired",
            streakId: "workout",
            expiresAt: pastDate
        )

        // Then: Should be expired
        #expect(freeze.isExpired == true)
    }

    @Test("isExpired false when expiresAt in future")
    func testIsExpiredFalse() throws {
        // Given: Freeze with expiration in the future
        let futureDate = Date().addingTimeInterval(86400) // 1 day from now
        let freeze = StreakFreeze(
            id: "not-expired",
            streakId: "workout",
            expiresAt: futureDate
        )

        // Then: Should not be expired
        #expect(freeze.isExpired == false)
    }

    @Test("isAvailable true when unused and not expired")
    func testIsAvailableTrue() throws {
        // Given: Freeze that is unused and not expired
        let freeze = StreakFreeze(
            id: "available",
            streakId: "workout",
            usedDate: nil,
            expiresAt: nil
        )

        // Then: Should be available
        #expect(freeze.isAvailable == true)
        #expect(freeze.isUsed == false)
        #expect(freeze.isExpired == false)
    }

    @Test("isAvailable false when used")
    func testIsAvailableFalseUsed() throws {
        // Given: Freeze that has been used
        let freeze = StreakFreeze(
            id: "used",
            streakId: "workout",
            usedDate: Date()
        )

        // Then: Should not be available
        #expect(freeze.isAvailable == false)
        #expect(freeze.isUsed == true)
    }

    @Test("isAvailable false when expired")
    func testIsAvailableFalseExpired() throws {
        // Given: Freeze that has expired
        let pastDate = Date().addingTimeInterval(-86400) // 1 day ago
        let freeze = StreakFreeze(
            id: "expired",
            streakId: "workout",
            usedDate: nil,
            expiresAt: pastDate
        )

        // Then: Should not be available
        #expect(freeze.isAvailable == false)
        #expect(freeze.isExpired == true)
    }

    // MARK: - Validation Tests

    @Test("isValid true for valid freeze")
    func testIsValidTrue() throws {
        // Given: Valid freeze with proper date ordering
        let earnedDate = Date(timeIntervalSince1970: 1609459200)
        let usedDate = Date(timeIntervalSince1970: 1609545600) // After earned
        let expiresAt = Date(timeIntervalSince1970: 1612137600) // After earned
        let freeze = StreakFreeze(
            id: "valid-freeze",
            streakId: "workout",
            earnedDate: earnedDate,
            usedDate: usedDate,
            expiresAt: expiresAt
        )

        // Then: Should be valid
        #expect(freeze.isValid == true)
    }

    @Test("isValid false when ID empty")
    func testIsValidFalseEmptyId() throws {
        // Given: Freeze with empty ID
        let freeze = StreakFreeze(id: "", streakId: "workout")

        // Then: Should be invalid
        #expect(freeze.isValid == false)
    }

    @Test("isValid false when usedDate before earnedDate")
    func testIsValidFalseUsedBeforeEarned() throws {
        // Given: Freeze with usedDate before earnedDate (invalid)
        let earnedDate = Date(timeIntervalSince1970: 1609545600)
        let usedDate = Date(timeIntervalSince1970: 1609459200) // Before earned!
        let freeze = StreakFreeze(
            id: "invalid-dates",
            streakId: "workout",
            earnedDate: earnedDate,
            usedDate: usedDate
        )

        // Then: Should be invalid
        #expect(freeze.isValid == false)
    }

    @Test("isValid false when expiresAt before earnedDate")
    func testIsValidFalseExpiresBeforeEarned() throws {
        // Given: Freeze with expiresAt before earnedDate (invalid)
        let earnedDate = Date(timeIntervalSince1970: 1609545600)
        let expiresAt = Date(timeIntervalSince1970: 1609459200) // Before earned!
        let freeze = StreakFreeze(
            id: "invalid-expiry",
            streakId: "workout",
            earnedDate: earnedDate,
            expiresAt: expiresAt
        )

        // Then: Should be invalid
        #expect(freeze.isValid == false)
    }

    // MARK: - Analytics Tests

    @Test("eventParameters includes all fields")
    func testEventParametersIncludesFields() throws {
        // Given: Freeze with all fields
        let earnedDate = Date(timeIntervalSince1970: 1609459200)
        let usedDate = Date(timeIntervalSince1970: 1609545600)
        let freeze = StreakFreeze(
            id: "analytics-test",
            streakId: "meditation",
            earnedDate: earnedDate,
            usedDate: usedDate,
            expiresAt: nil
        )

        // When: Getting event parameters
        let params = freeze.eventParameters

        // Then: Should include all fields with streak_freeze_ prefix
        #expect(params["streak_freeze_id"] as? String == "analytics-test")
        #expect(params["streak_freeze_streak_id"] as? String == "meditation")
        #expect(params["streak_freeze_is_used"] as? Bool == true)
        #expect(params["streak_freeze_is_expired"] as? Bool == false)
        #expect(params["streak_freeze_is_available"] as? Bool == false)
        #expect(params["streak_freeze_earned_date"] as? Double == earnedDate.timeIntervalSince1970)
        #expect(params["streak_freeze_used_date"] as? Double == usedDate.timeIntervalSince1970)
    }

    @Test("eventParameters prefixed with streak_freeze_")
    func testEventParametersPrefixed() throws {
        // Given: Freeze with specific streakId
        let freeze = StreakFreeze(id: "test", streakId: "running")

        // When: Getting event parameters
        let params = freeze.eventParameters

        // Then: Should prefix all keys with streak_freeze_
        #expect(params["streak_freeze_id"] as? String == "test")
        #expect(params["streak_freeze_streak_id"] as? String == "running")
        #expect(params["streak_freeze_is_used"] != nil)
        #expect(params["streak_freeze_is_expired"] != nil)
        #expect(params["streak_freeze_is_available"] != nil)
    }

    @Test("eventParameters includes availability status")
    func testEventParametersIncludesAvailability() throws {
        // Given: Different freeze states
        let available = StreakFreeze.mockUnused()
        let used = StreakFreeze.mockUsed()
        let expired = StreakFreeze.mockExpired()

        // When: Getting event parameters
        let availableParams = available.eventParameters
        let usedParams = used.eventParameters
        let expiredParams = expired.eventParameters

        // Then: Should include correct availability status with streak_freeze_ prefix
        #expect(availableParams["streak_freeze_is_available"] as? Bool == true)
        #expect(usedParams["streak_freeze_is_available"] as? Bool == false)
        #expect(expiredParams["streak_freeze_is_available"] as? Bool == false)
    }

    // MARK: - Equatable Tests

    @Test("Same freezes are equal")
    func testEquatableEqual() throws {
        // Given: Two freezes with identical values
        let earnedDate = Date(timeIntervalSince1970: 1609459200)
        let freeze1 = StreakFreeze(
            id: "same-id",
            streakId: "cardio",
            earnedDate: earnedDate,
            usedDate: nil,
            expiresAt: nil
        )
        let freeze2 = StreakFreeze(
            id: "same-id",
            streakId: "cardio",
            earnedDate: earnedDate,
            usedDate: nil,
            expiresAt: nil
        )

        // Then: Should be equal
        #expect(freeze1 == freeze2)
    }

    @Test("Different IDs make freezes unequal")
    func testEquatableUnequalId() throws {
        // Given: Two freezes differing only in ID
        let freeze1 = StreakFreeze(id: "id-1", streakId: "workout")
        let freeze2 = StreakFreeze(id: "id-2", streakId: "workout")

        // Then: Should not be equal
        #expect(freeze1 != freeze2)
    }

    @Test("Different streakIds make freezes unequal")
    func testEquatableUnequalStreakId() throws {
        // Given: Two freezes differing only in streakId
        let freeze1 = StreakFreeze(id: "same-id", streakId: "workout")
        let freeze2 = StreakFreeze(id: "same-id", streakId: "meditation")

        // Then: Should not be equal
        #expect(freeze1 != freeze2)
    }
}
