//
//  StreakConfigurationTests.swift
//  SwiftfulGamificationTests
//
//  Tests for StreakConfiguration model
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("StreakConfiguration Tests")
struct StreakConfigurationTests {

    // MARK: - Initialization Tests

    @Test("Init with streakId creates basic configuration")
    func testInitWithStreakId() throws {
        // Given: A streak ID
        let streakId = "workout"

        // When: Initializing with only the streak ID (using default parameters)
        let config = StreakConfiguration(streakKey: streakId)

        // Then: Should create configuration with default values
        #expect(config.streakKey == streakId)
        #expect(config.eventsRequiredPerDay == 1)
        #expect(config.useServerCalculation == false)
        #expect(config.leewayHours == 0)
        #expect(config.autoConsumeFreeze == true)

        // And: Computed properties should reflect default state
        #expect(config.isGoalBasedStreak == false) // eventsRequiredPerDay = 1
        #expect(config.isStrictMode == true)        // leewayHours = 0
        #expect(config.isTravelFriendly == false)   // leewayHours < 12
    }

    @Test("Init with all parameters creates complete configuration")
    func testInitWithAllParameters() throws {
        // Given: Custom values for all parameters
        let streakId = "reading"
        let eventsRequiredPerDay = 5
        let useServerCalculation = true
        let leewayHours = 12
        let autoConsumeFreeze = false

        // When: Initializing with all custom parameters
        let config = StreakConfiguration(
            streakKey: streakId,
            eventsRequiredPerDay: eventsRequiredPerDay,
            useServerCalculation: useServerCalculation,
            leewayHours: leewayHours,
            autoConsumeFreeze: autoConsumeFreeze
        )

        // Then: All properties should match the provided values
        #expect(config.streakKey == streakId)
        #expect(config.eventsRequiredPerDay == eventsRequiredPerDay)
        #expect(config.useServerCalculation == useServerCalculation)
        #expect(config.leewayHours == leewayHours)
        #expect(config.autoConsumeFreeze == autoConsumeFreeze)

        // And: Computed properties should reflect custom state
        #expect(config.isGoalBasedStreak == true)  // eventsRequiredPerDay = 5 > 1
        #expect(config.isStrictMode == false)       // leewayHours = 12 > 0
        #expect(config.isTravelFriendly == true)    // leewayHours = 12 >= 12
    }

    @Test("Init validates eventsRequiredPerDay >= 1", .disabled("Precondition failures cannot be caught in tests"))
    func testInitValidatesEventsRequired() throws {
        // Note: This would crash with precondition failure if eventsRequiredPerDay < 1
        // Cannot test in unit tests as preconditions terminate the process
        // Manual verification: StreakConfiguration(streakKey: "test", eventsRequiredPerDay: 0)
        // Expected: "precondition failed: eventsRequiredPerDay must be >= 1"
    }

    @Test("Init validates leewayHours >= 0", .disabled("Precondition failures cannot be caught in tests"))
    func testInitValidatesLeewayMin() throws {
        // Note: This would crash with precondition failure if leewayHours < 0
        // Cannot test in unit tests as preconditions terminate the process
        // Manual verification: StreakConfiguration(streakKey: "test", leewayHours: -1)
        // Expected: "precondition failed: leewayHours must be >= 0"
    }

    @Test("Init validates leewayHours <= 24", .disabled("Precondition failures cannot be caught in tests"))
    func testInitValidatesLeewayMax() throws {
        // Note: This would crash with precondition failure if leewayHours > 24
        // Cannot test in unit tests as preconditions terminate the process
        // Manual verification: StreakConfiguration(streakKey: "test", leewayHours: 25)
        // Expected: "precondition failed: leewayHours must be <= 24"
    }

    // MARK: - Mock Factory Tests

    @Test("Mock creates basic configuration")
    func testMockCreatesBasic() throws {
        // When: Creating a mock configuration with defaults
        let config = StreakConfiguration.mock()

        // Then: Should create valid configuration
        #expect(config.streakKey == "workout")
        #expect(config.eventsRequiredPerDay == 1)
        #expect(config.useServerCalculation == false)
        #expect(config.leewayHours == 0)
        #expect(config.autoConsumeFreeze == true)
    }

    @Test("Mock basic creates default settings")
    func testMockBasicDefaults() throws {
        // When: Creating a mockDefault configuration
        let config = StreakConfiguration.mockDefault()

        // Then: Should create basic streak configuration
        #expect(config.streakKey == "workout")
        #expect(config.eventsRequiredPerDay == 1)
        #expect(config.useServerCalculation == false)
        #expect(config.leewayHours == 0)
        #expect(config.autoConsumeFreeze == true)

        // And: Should match characteristics of basic streak
        #expect(config.isGoalBasedStreak == false)
        #expect(config.isStrictMode == true)
        #expect(config.isTravelFriendly == false)
    }

    @Test("Mock goal-based creates configuration with eventsRequiredPerDay")
    func testMockGoalBasedConfiguration() throws {
        // When: Creating a mockGoalBased configuration with custom goal
        let config = StreakConfiguration.mockGoalBased(eventsRequiredPerDay: 5)

        // Then: Should create goal-based configuration
        #expect(config.streakKey == "workout")
        #expect(config.eventsRequiredPerDay == 5)
        #expect(config.useServerCalculation == false)
        #expect(config.leewayHours == 0)
        #expect(config.autoConsumeFreeze == true)

        // And: Should be recognized as goal-based
        #expect(config.isGoalBasedStreak == true)
    }

    @Test("Mock lenient creates configuration with leewayHours")
    func testMockLenientConfiguration() throws {
        // When: Creating a mockLenient configuration with custom leeway
        let config = StreakConfiguration.mockLenient(leewayHours: 6)

        // Then: Should create lenient configuration
        #expect(config.streakKey == "workout")
        #expect(config.eventsRequiredPerDay == 1)
        #expect(config.useServerCalculation == false)
        #expect(config.leewayHours == 6)
        #expect(config.autoConsumeFreeze == true)

        // And: Should not be strict mode
        #expect(config.isStrictMode == false)
        // But: Should not be travel-friendly (6 < 12)
        #expect(config.isTravelFriendly == false)
    }

    @Test("Mock travel-friendly creates 24-hour leeway")
    func testMockTravelFriendlyConfiguration() throws {
        // When: Creating a mockTravelFriendly configuration
        let config = StreakConfiguration.mockTravelFriendly()

        // Then: Should create travel-friendly configuration
        #expect(config.streakKey == "workout")
        #expect(config.eventsRequiredPerDay == 1)
        #expect(config.useServerCalculation == false)
        #expect(config.leewayHours == 24)
        #expect(config.autoConsumeFreeze == true)

        // And: Should be recognized as travel-friendly
        #expect(config.isTravelFriendly == true)
        #expect(config.isStrictMode == false)
    }

    @Test("Mock server calculation creates with useServerCalculation = true")
    func testMockServerCalculationConfiguration() throws {
        // When: Creating a mockServerCalculation configuration
        let config = StreakConfiguration.mockServerCalculation()

        // Then: Should create server-calculated configuration
        #expect(config.streakKey == "workout")
        #expect(config.eventsRequiredPerDay == 1)
        #expect(config.useServerCalculation == true)
        #expect(config.leewayHours == 0)
        #expect(config.autoConsumeFreeze == true)
    }

    // MARK: - Codable Tests

    @Test("Encodes to snake_case keys")
    func testEncodesToSnakeCase() throws {
        // Given: A configuration with known values
        let config = StreakConfiguration(
            streakKey: "reading",
            eventsRequiredPerDay: 3,
            useServerCalculation: true,
            leewayHours: 6,
            autoConsumeFreeze: false
        )

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then: Should use snake_case keys
        #expect(json["streak_id"] as? String == "reading")
        #expect(json["events_required_per_day"] as? Int == 3)
        #expect(json["use_server_calculation"] as? Bool == true)
        #expect(json["leeway_hours"] as? Int == 6)
        #expect(json["auto_consume_freeze"] as? Bool == false)

        // And: Should not contain camelCase keys
        #expect(json["streakId"] == nil)
        #expect(json["eventsRequiredPerDay"] == nil)
        #expect(json["useServerCalculation"] == nil)
        #expect(json["leewayHours"] == nil)
        #expect(json["autoConsumeFreeze"] == nil)
    }

    @Test("Decodes from snake_case keys")
    func testDecodesFromSnakeCase() throws {
        // Given: JSON with snake_case keys
        let json = """
        {
            "streak_id": "meditation",
            "events_required_per_day": 2,
            "use_server_calculation": true,
            "leeway_hours": 12,
            "auto_consume_freeze": false
        }
        """
        let data = json.data(using: .utf8)!

        // When: Decoding from JSON
        let decoder = JSONDecoder()
        let config = try decoder.decode(StreakConfiguration.self, from: data)

        // Then: Should decode all properties correctly
        #expect(config.streakKey == "meditation")
        #expect(config.eventsRequiredPerDay == 2)
        #expect(config.useServerCalculation == true)
        #expect(config.leewayHours == 12)
        #expect(config.autoConsumeFreeze == false)
    }

    @Test("Roundtrip preserves all data")
    func testRoundtripPreservesData() throws {
        // Given: Original configuration
        let original = StreakConfiguration(
            streakKey: "journaling",
            eventsRequiredPerDay: 7,
            useServerCalculation: false,
            leewayHours: 18,
            autoConsumeFreeze: true
        )

        // When: Encoding and then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StreakConfiguration.self, from: data)

        // Then: Should preserve all data
        #expect(decoded == original)
        #expect(decoded.streakKey == original.streakKey)
        #expect(decoded.eventsRequiredPerDay == original.eventsRequiredPerDay)
        #expect(decoded.useServerCalculation == original.useServerCalculation)
        #expect(decoded.leewayHours == original.leewayHours)
        #expect(decoded.autoConsumeFreeze == original.autoConsumeFreeze)
    }

    // MARK: - Computed Property Tests

    @Test("isGoalBasedStreak true when eventsRequiredPerDay > 1")
    func testIsGoalBasedTrue() throws {
        // Given: Configuration with multiple events required per day
        let config = StreakConfiguration(streakKey: "test", eventsRequiredPerDay: 3)

        // Then: Should be goal-based
        #expect(config.isGoalBasedStreak == true)
    }

    @Test("isGoalBasedStreak false when eventsRequiredPerDay = 1")
    func testIsGoalBasedFalse() throws {
        // Given: Configuration with single event required per day
        let config = StreakConfiguration(streakKey: "test", eventsRequiredPerDay: 1)

        // Then: Should not be goal-based
        #expect(config.isGoalBasedStreak == false)
    }

    @Test("isStrictMode true when leewayHours = 0")
    func testIsStrictModeTrue() throws {
        // Given: Configuration with no leeway
        let config = StreakConfiguration(streakKey: "test", leewayHours: 0)

        // Then: Should be strict mode
        #expect(config.isStrictMode == true)
    }

    @Test("isStrictMode false when leewayHours > 0")
    func testIsStrictModeFalse() throws {
        // Given: Configuration with leeway
        let config = StreakConfiguration(streakKey: "test", leewayHours: 3)

        // Then: Should not be strict mode
        #expect(config.isStrictMode == false)
    }

    @Test("isTravelFriendly true when leewayHours >= 12")
    func testIsTravelFriendlyTrue() throws {
        // Given: Configuration with large leeway (exactly 12 hours)
        let config = StreakConfiguration(streakKey: "test", leewayHours: 12)

        // Then: Should be travel-friendly
        #expect(config.isTravelFriendly == true)
    }

    @Test("isTravelFriendly false when leewayHours < 12")
    func testIsTravelFriendlyFalse() throws {
        // Given: Configuration with small leeway (11 hours)
        let config = StreakConfiguration(streakKey: "test", leewayHours: 11)

        // Then: Should not be travel-friendly
        #expect(config.isTravelFriendly == false)
    }

    // MARK: - Equatable Tests

    @Test("Same configurations are equal")
    func testEquatableEqual() throws {
        // Given: Two configurations with identical values
        let config1 = StreakConfiguration(
            streakKey: "workout",
            eventsRequiredPerDay: 3,
            useServerCalculation: true,
            leewayHours: 6,
            autoConsumeFreeze: false
        )
        let config2 = StreakConfiguration(
            streakKey: "workout",
            eventsRequiredPerDay: 3,
            useServerCalculation: true,
            leewayHours: 6,
            autoConsumeFreeze: false
        )

        // Then: Should be equal
        #expect(config1 == config2)
    }

    @Test("Different streakId makes configurations unequal")
    func testEquatableUnequalStreakId() throws {
        // Given: Two configurations differing only in streakId
        let config1 = StreakConfiguration(streakKey: "workout")
        let config2 = StreakConfiguration(streakKey: "meditation")

        // Then: Should not be equal
        #expect(config1 != config2)
    }

    @Test("Different eventsRequiredPerDay makes configurations unequal")
    func testEquatableUnequalEventsRequired() throws {
        // Given: Two configurations differing only in eventsRequiredPerDay
        let config1 = StreakConfiguration(streakKey: "workout", eventsRequiredPerDay: 1)
        let config2 = StreakConfiguration(streakKey: "workout", eventsRequiredPerDay: 3)

        // Then: Should not be equal
        #expect(config1 != config2)
    }
}
