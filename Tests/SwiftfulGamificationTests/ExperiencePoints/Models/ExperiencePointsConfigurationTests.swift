//
//  ExperiencePointsConfigurationTests.swift
//  SwiftfulGamificationTests
//
//  Tests for ExperiencePointsConfiguration model
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("ExperiencePointsConfiguration Tests")
struct ExperiencePointsConfigurationTests {

    // MARK: - Initialization Tests

    @Test("Init with experienceId creates basic configuration")
    func testInitWithExperienceId() throws {
        // Given: An experience ID
        let experienceId = "main"

        // When: Initializing with only the experience ID (using default parameters)
        let config = ExperiencePointsConfiguration(experienceKey: experienceId)

        // Then: Should create configuration with default values
        #expect(config.experienceKey == experienceId)
        #expect(config.useServerCalculation == false)
    }

    @Test("Init with all parameters creates complete configuration")
    func testInitWithAllParameters() throws {
        // Given: Custom values for all parameters
        let experienceId = "battle"
        let useServerCalculation = true

        // When: Initializing with all custom parameters
        let config = ExperiencePointsConfiguration(
            experienceKey: experienceId,
            useServerCalculation: useServerCalculation
        )

        // Then: All properties should match the provided values
        #expect(config.experienceKey == experienceId)
        #expect(config.useServerCalculation == useServerCalculation)
    }

    // MARK: - Mock Factory Tests

    @Test("Mock creates basic configuration")
    func testMockCreatesBasic() throws {
        // When: Creating a mock configuration with defaults
        let config = ExperiencePointsConfiguration.mock()

        // Then: Should create valid configuration
        #expect(config.experienceKey == "main")
        #expect(config.useServerCalculation == false)
    }

    @Test("Mock basic creates default settings")
    func testMockBasicDefaults() throws {
        // When: Creating a mockBasic configuration
        let config = ExperiencePointsConfiguration.mockBasic()

        // Then: Should create basic XP configuration
        #expect(config.experienceKey == "main")
        #expect(config.useServerCalculation == false)
    }

    @Test("Mock server calculation creates with useServerCalculation = true")
    func testMockServerCalculationConfiguration() throws {
        // When: Creating a mockServerCalculation configuration
        let config = ExperiencePointsConfiguration.mockServerCalculation()

        // Then: Should create server-calculated configuration
        #expect(config.experienceKey == "main")
        #expect(config.useServerCalculation == true)
    }

    // MARK: - Codable Tests

    @Test("Encodes to snake_case keys")
    func testEncodesToSnakeCase() throws {
        // Given: A configuration with known values
        let config = ExperiencePointsConfiguration(
            experienceKey: "battle",
            useServerCalculation: true
        )

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Then: Should use snake_case keys
        #expect(json["experience_id"] as? String == "battle")
        #expect(json["use_server_calculation"] as? Bool == true)

        // And: Should not contain camelCase keys
        #expect(json["experienceId"] == nil)
        #expect(json["useServerCalculation"] == nil)
    }

    @Test("Decodes from snake_case keys")
    func testDecodesFromSnakeCase() throws {
        // Given: JSON with snake_case keys
        let json = """
        {
            "experience_id": "quest",
            "use_server_calculation": true
        }
        """
        let data = json.data(using: .utf8)!

        // When: Decoding from JSON
        let decoder = JSONDecoder()
        let config = try decoder.decode(ExperiencePointsConfiguration.self, from: data)

        // Then: Should decode all properties correctly
        #expect(config.experienceKey == "quest")
        #expect(config.useServerCalculation == true)
    }

    @Test("Roundtrip preserves all data")
    func testRoundtripPreservesData() throws {
        // Given: Original configuration
        let original = ExperiencePointsConfiguration(
            experienceKey: "arena",
            useServerCalculation: false
        )

        // When: Encoding and then decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ExperiencePointsConfiguration.self, from: data)

        // Then: Should preserve all data
        #expect(decoded == original)
        #expect(decoded.experienceKey == original.experienceKey)
        #expect(decoded.useServerCalculation == original.useServerCalculation)
    }

    // MARK: - Equatable Tests

    @Test("Same configurations are equal")
    func testEquatableEqual() throws {
        // Given: Two configurations with identical values
        let config1 = ExperiencePointsConfiguration(
            experienceKey: "main",
            useServerCalculation: true
        )
        let config2 = ExperiencePointsConfiguration(
            experienceKey: "main",
            useServerCalculation: true
        )

        // Then: Should be equal
        #expect(config1 == config2)
    }

    @Test("Different experienceId makes configurations unequal")
    func testEquatableUnequalExperienceId() throws {
        // Given: Two configurations differing only in experienceId
        let config1 = ExperiencePointsConfiguration(experienceKey: "main")
        let config2 = ExperiencePointsConfiguration(experienceKey: "battle")

        // Then: Should not be equal
        #expect(config1 != config2)
    }

    @Test("Different useServerCalculation makes configurations unequal")
    func testEquatableUnequalServerCalculation() throws {
        // Given: Two configurations differing only in useServerCalculation
        let config1 = ExperiencePointsConfiguration(experienceKey: "main", useServerCalculation: false)
        let config2 = ExperiencePointsConfiguration(experienceKey: "main", useServerCalculation: true)

        // Then: Should not be equal
        #expect(config1 != config2)
    }
}
