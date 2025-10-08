//
//  FileManagerExperiencePointsPersistenceTests.swift
//  SwiftfulGamification
//
//  Tests for FileManagerExperiencePointsPersistence
//

import Testing
import Foundation
@testable import SwiftfulGamification

@MainActor
@Suite("FileManagerExperiencePointsPersistence Tests")
struct FileManagerExperiencePointsPersistenceTests {

    // MARK: - Save and Retrieve

    @Test("Save and retrieve CurrentExperiencePointsData successfully")
    func saveAndRetrieveData() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        // Create test data
        let testData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 5000,
            totalEvents: 100,
            createdAt: Date(),
            updatedAt: Date()
        )

        // Save data
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", testData)

        // Retrieve data
        let retrieved = persistence.getSavedExperiencePointsData(experienceKey: "test")

        // Verify
        #expect(retrieved != nil)
        #expect(retrieved?.experienceKey == testData.experienceKey)
        #expect(retrieved?.totalPoints == testData.totalPoints)
        #expect(retrieved?.totalEvents == testData.totalEvents)

        // Clean up
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", nil)
    }

    @Test("Retrieve returns nil when no data saved")
    func retrieveReturnsNilWhenEmpty() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        // Clean up any existing data
        try? persistence.saveCurrentExperiencePointsData(experienceKey: "test", nil)

        // Retrieve should return nil
        let retrieved = persistence.getSavedExperiencePointsData(experienceKey: "test")
        #expect(retrieved == nil)
    }

    @Test("Save nil clears existing data")
    func saveNilClearsData() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        // Save some data
        let testData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 3000,
            totalEvents: 50,
            createdAt: Date(),
            updatedAt: Date()
        )
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", testData)

        // Verify it was saved
        #expect(persistence.getSavedExperiencePointsData(experienceKey: "test") != nil)

        // Save nil
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", nil)

        // Verify it was cleared
        #expect(persistence.getSavedExperiencePointsData(experienceKey: "test") == nil)
    }

    @Test("Overwrite existing data with new data")
    func overwriteExistingData() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        // Save initial data
        let initialData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 5000,
            totalEvents: 100,
            createdAt: Date(),
            updatedAt: Date()
        )
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", initialData)

        // Save new data
        let newData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 7000,
            totalEvents: 150,
            createdAt: Date(),
            updatedAt: Date()
        )
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", newData)

        // Retrieve and verify it's the new data
        let retrieved = persistence.getSavedExperiencePointsData(experienceKey: "test")
        #expect(retrieved?.totalPoints == 7000)
        #expect(retrieved?.totalEvents == 150)

        // Clean up
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", nil)
    }

    // MARK: - Data Integrity

    @Test("Save and retrieve preserves all properties")
    func preservesAllProperties() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        let now = Date()
        let createdDate = Calendar.current.date(byAdding: .day, value: -30, to: now)!

        let testData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 10000,
            totalEvents: 250,
            createdAt: createdDate,
            updatedAt: now
        )

        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", testData)
        let retrieved = persistence.getSavedExperiencePointsData(experienceKey: "test")

        #expect(retrieved?.experienceKey == testData.experienceKey)
        #expect(retrieved?.totalPoints == testData.totalPoints)
        #expect(retrieved?.totalEvents == testData.totalEvents)

        // Date comparison (within 1 second tolerance due to JSON encoding precision)
        if let retrievedCreated = retrieved?.createdAt {
            #expect(abs(retrievedCreated.timeIntervalSince(testData.createdAt!)) < 1)
        } else {
            Issue.record("createdAt should not be nil")
        }

        if let retrievedUpdated = retrieved?.updatedAt {
            #expect(abs(retrievedUpdated.timeIntervalSince(testData.updatedAt!)) < 1)
        } else {
            Issue.record("updatedAt should not be nil")
        }

        // Clean up
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", nil)
    }

    @Test("Save and retrieve with nil optional fields")
    func preservesNilOptionalFields() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        let testData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: nil,
            totalEvents: nil,
            createdAt: nil,
            updatedAt: nil
        )

        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", testData)
        let retrieved = persistence.getSavedExperiencePointsData(experienceKey: "test")

        #expect(retrieved?.experienceKey == "test")
        #expect(retrieved?.totalPoints == nil)
        #expect(retrieved?.totalEvents == nil)
        #expect(retrieved?.createdAt == nil)
        #expect(retrieved?.updatedAt == nil)

        // Clean up
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", nil)
    }

    // MARK: - Multiple Instances

    @Test("Multiple instances share same data")
    func multipleInstancesShareData() async throws {
        let persistence1 = FileManagerExperiencePointsPersistence()
        let persistence2 = FileManagerExperiencePointsPersistence()

        let testData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 8000,
            totalEvents: 200,
            createdAt: Date(),
            updatedAt: Date()
        )

        // Save with first instance
        try persistence1.saveCurrentExperiencePointsData(experienceKey: "test", testData)

        // Retrieve with second instance
        let retrieved = persistence2.getSavedExperiencePointsData(experienceKey: "test")

        #expect(retrieved?.experienceKey == "test")
        #expect(retrieved?.totalPoints == 8000)
        #expect(retrieved?.totalEvents == 200)

        // Clean up with either instance
        try persistence1.saveCurrentExperiencePointsData(experienceKey: "test", nil)

        // Verify both see it as cleared
        #expect(persistence1.getSavedExperiencePointsData(experienceKey: "test") == nil)
        #expect(persistence2.getSavedExperiencePointsData(experienceKey: "test") == nil)
    }

    // MARK: - Edge Cases

    @Test("Save and retrieve zero values")
    func saveRetrieveZeroValues() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        let testData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 0,
            totalEvents: 0,
            createdAt: Date(),
            updatedAt: Date()
        )

        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", testData)
        let retrieved = persistence.getSavedExperiencePointsData(experienceKey: "test")

        #expect(retrieved?.experienceKey == "test")
        #expect(retrieved?.totalPoints == 0)
        #expect(retrieved?.totalEvents == 0)

        // Clean up
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", nil)
    }

    @Test("Save and retrieve large values")
    func saveLargeValues() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        let testData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 9999999,
            totalEvents: 500000,
            createdAt: Date(),
            updatedAt: Date()
        )

        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", testData)
        let retrieved = persistence.getSavedExperiencePointsData(experienceKey: "test")

        #expect(retrieved?.experienceKey == "test")
        #expect(retrieved?.totalPoints == 9999999)
        #expect(retrieved?.totalEvents == 500000)

        // Clean up
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", nil)
    }

    @Test("Retrieve after clearing returns nil")
    func retrieveAfterClearingReturnsNil() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        // Save data
        let testData = CurrentExperiencePointsData(
            experienceKey: "test",
            totalPoints: 5000,
            totalEvents: 100,
            createdAt: Date(),
            updatedAt: Date()
        )
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", testData)

        // Clear
        try persistence.saveCurrentExperiencePointsData(experienceKey: "test", nil)

        // Retrieve should return nil
        #expect(persistence.getSavedExperiencePointsData(experienceKey: "test") == nil)
    }

    @Test("Different experienceIds store data separately")
    func differentExperienceIdsStoreSeparately() async throws {
        let persistence = FileManagerExperiencePointsPersistence()

        // Save data for "main" experience
        let mainData = CurrentExperiencePointsData(
            experienceKey: "main",
            totalPoints: 5000,
            totalEvents: 100,
            createdAt: Date(),
            updatedAt: Date()
        )
        try persistence.saveCurrentExperiencePointsData(experienceKey: "main", mainData)

        // Save data for "battle" experience
        let battleData = CurrentExperiencePointsData(
            experienceKey: "battle",
            totalPoints: 7000,
            totalEvents: 150,
            createdAt: Date(),
            updatedAt: Date()
        )
        try persistence.saveCurrentExperiencePointsData(experienceKey: "battle", battleData)

        // Retrieve both and verify they're separate
        let retrievedMain = persistence.getSavedExperiencePointsData(experienceKey: "main")
        let retrievedBattle = persistence.getSavedExperiencePointsData(experienceKey: "battle")

        #expect(retrievedMain?.experienceKey == "main")
        #expect(retrievedMain?.totalPoints == 5000)
        #expect(retrievedMain?.totalEvents == 100)

        #expect(retrievedBattle?.experienceKey == "battle")
        #expect(retrievedBattle?.totalPoints == 7000)
        #expect(retrievedBattle?.totalEvents == 150)

        // Clean up both
        try persistence.saveCurrentExperiencePointsData(experienceKey: "main", nil)
        try persistence.saveCurrentExperiencePointsData(experienceKey: "battle", nil)
    }
}
