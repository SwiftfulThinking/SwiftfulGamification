//
//  FileManagerStreakPersistenceTests.swift
//  SwiftfulGamification
//
//  Tests for FileManagerStreakPersistence
//

import Testing
import Foundation
@testable import SwiftfulGamification

@MainActor
@Suite("FileManagerStreakPersistence Tests")
struct FileManagerStreakPersistenceTests {

    // MARK: - Save and Retrieve

    @Test("Save and retrieve CurrentStreakData successfully")
    func saveAndRetrieveStreakData() async throws {
        let persistence = FileManagerStreakPersistence()

        // Create test data
        let testData = CurrentStreakData(
            streakId: "test",
            currentStreak: 5,
            longestStreak: 10,
            lastEventDate: Date(),
            streakStartDate: Date(),
            freezesRemaining: 2,
            updatedAt: Date()
        )

        // Save data
        try persistence.saveCurrentStreakData(streakId: "test", testData)

        // Retrieve data
        let retrieved = persistence.getSavedStreakData(streakId: "test")

        // Verify
        #expect(retrieved != nil)
        #expect(retrieved?.streakId == testData.streakId)
        #expect(retrieved?.currentStreak == testData.currentStreak)
        #expect(retrieved?.longestStreak == testData.longestStreak)
        #expect(retrieved?.freezesRemaining == testData.freezesRemaining)

        // Clean up
        try persistence.saveCurrentStreakData(streakId: "test", nil)
    }

    @Test("Retrieve returns nil when no data saved")
    func retrieveReturnsNilWhenEmpty() async throws {
        let persistence = FileManagerStreakPersistence()

        // Clean up any existing data
        try? persistence.saveCurrentStreakData(streakId: "test", nil)

        // Retrieve should return nil
        let retrieved = persistence.getSavedStreakData(streakId: "test")
        #expect(retrieved == nil)
    }

    @Test("Save nil clears existing data")
    func saveNilClearsData() async throws {
        let persistence = FileManagerStreakPersistence()

        // Save some data
        let testData = CurrentStreakData(
            streakId: "test",
            currentStreak: 3,
            longestStreak: 5,
            lastEventDate: Date(),
            streakStartDate: Date(),
            freezesRemaining: 1,
            updatedAt: Date()
        )
        try persistence.saveCurrentStreakData(streakId: "test", testData)

        // Verify it was saved
        #expect(persistence.getSavedStreakData(streakId: "test") != nil)

        // Save nil
        try persistence.saveCurrentStreakData(streakId: "test", nil)

        // Verify it was cleared
        #expect(persistence.getSavedStreakData(streakId: "test") == nil)
    }

    @Test("Overwrite existing data with new data")
    func overwriteExistingData() async throws {
        let persistence = FileManagerStreakPersistence()

        // Save initial data
        let initialData = CurrentStreakData(
            streakId: "test",
            currentStreak: 5,
            longestStreak: 10,
            lastEventDate: Date(),
            streakStartDate: Date(),
            freezesRemaining: 2,
            updatedAt: Date()
        )
        try persistence.saveCurrentStreakData(streakId: "test", initialData)

        // Save new data
        let newData = CurrentStreakData(
            streakId: "test",
            currentStreak: 7,
            longestStreak: 12,
            lastEventDate: Date(),
            streakStartDate: Date(),
            freezesRemaining: 3,
            updatedAt: Date()
        )
        try persistence.saveCurrentStreakData(streakId: "test", newData)

        // Retrieve and verify it's the new data
        let retrieved = persistence.getSavedStreakData(streakId: "test")
        #expect(retrieved?.currentStreak == 7)
        #expect(retrieved?.longestStreak == 12)
        #expect(retrieved?.freezesRemaining == 3)

        // Clean up
        try persistence.saveCurrentStreakData(streakId: "test", nil)
    }

    // MARK: - Data Integrity

    @Test("Save and retrieve preserves all properties")
    func preservesAllProperties() async throws {
        let persistence = FileManagerStreakPersistence()

        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!

        let testData = CurrentStreakData(
            streakId: "test",
            currentStreak: 10,
            longestStreak: 15,
            lastEventDate: now,
            lastEventTimezone: "America/New_York",
            streakStartDate: startDate,
            totalEvents: 25,
            freezesRemaining: 5,
            createdAt: startDate,
            updatedAt: now,
            eventsRequiredPerDay: 1,
            todayEventCount: 3
        )

        try persistence.saveCurrentStreakData(streakId: "test", testData)
        let retrieved = persistence.getSavedStreakData(streakId: "test")

        #expect(retrieved?.streakId == testData.streakId)
        #expect(retrieved?.currentStreak == testData.currentStreak)
        #expect(retrieved?.longestStreak == testData.longestStreak)
        #expect(retrieved?.freezesRemaining == testData.freezesRemaining)
        #expect(retrieved?.lastEventTimezone == testData.lastEventTimezone)
        #expect(retrieved?.totalEvents == testData.totalEvents)
        #expect(retrieved?.eventsRequiredPerDay == testData.eventsRequiredPerDay)
        #expect(retrieved?.todayEventCount == testData.todayEventCount)

        // Date comparison (within 1 second tolerance due to JSON encoding precision)
        if let retrievedStart = retrieved?.streakStartDate {
            #expect(abs(retrievedStart.timeIntervalSince(testData.streakStartDate!)) < 1)
        } else {
            Issue.record("streakStartDate should not be nil")
        }

        if let retrievedLast = retrieved?.lastEventDate {
            #expect(abs(retrievedLast.timeIntervalSince(testData.lastEventDate!)) < 1)
        } else {
            Issue.record("lastEventDate should not be nil")
        }

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
        try persistence.saveCurrentStreakData(streakId: "test", nil)
    }

    @Test("Save and retrieve with nil optional fields")
    func preservesNilOptionalFields() async throws {
        let persistence = FileManagerStreakPersistence()

        let testData = CurrentStreakData(
            streakId: "test",
            currentStreak: nil,
            longestStreak: nil,
            lastEventDate: nil,
            lastEventTimezone: nil,
            streakStartDate: nil,
            totalEvents: nil,
            freezesRemaining: nil,
            createdAt: nil,
            updatedAt: nil,
            eventsRequiredPerDay: nil,
            todayEventCount: nil,
            recentEvents: nil
        )

        try persistence.saveCurrentStreakData(streakId: "test", testData)
        let retrieved = persistence.getSavedStreakData(streakId: "test")

        #expect(retrieved?.streakId == "test")
        #expect(retrieved?.currentStreak == nil)
        #expect(retrieved?.longestStreak == nil)
        #expect(retrieved?.lastEventDate == nil)
        #expect(retrieved?.lastEventTimezone == nil)
        #expect(retrieved?.streakStartDate == nil)
        #expect(retrieved?.totalEvents == nil)
        #expect(retrieved?.freezesRemaining == nil)
        #expect(retrieved?.createdAt == nil)
        #expect(retrieved?.updatedAt == nil)
        #expect(retrieved?.eventsRequiredPerDay == nil)
        #expect(retrieved?.todayEventCount == nil)
        #expect(retrieved?.recentEvents == nil)

        // Clean up
        try persistence.saveCurrentStreakData(streakId: "test", nil)
    }

    // MARK: - Multiple Instances

    @Test("Multiple instances share same data")
    func multipleInstancesShareData() async throws {
        let persistence1 = FileManagerStreakPersistence()
        let persistence2 = FileManagerStreakPersistence()

        let testData = CurrentStreakData(
            streakId: "test",
            currentStreak: 8,
            longestStreak: 12,
            lastEventDate: Date(),
            streakStartDate: Date(),
            freezesRemaining: 3,
            updatedAt: Date()
        )

        // Save with first instance
        try persistence1.saveCurrentStreakData(streakId: "test", testData)

        // Retrieve with second instance
        let retrieved = persistence2.getSavedStreakData(streakId: "test")

        #expect(retrieved?.streakId == "test")
        #expect(retrieved?.currentStreak == 8)
        #expect(retrieved?.longestStreak == 12)

        // Clean up with either instance
        try persistence1.saveCurrentStreakData(streakId: "test", nil)

        // Verify both see it as cleared
        #expect(persistence1.getSavedStreakData(streakId: "test") == nil)
        #expect(persistence2.getSavedStreakData(streakId: "test") == nil)
    }

    // MARK: - Edge Cases

    @Test("Save and retrieve zero values")
    func saveRetrieveZeroValues() async throws {
        let persistence = FileManagerStreakPersistence()

        let testData = CurrentStreakData(
            streakId: "test",
            currentStreak: 0,
            longestStreak: 0,
            lastEventDate: Date(),
            streakStartDate: Date(),
            totalEvents: 0,
            freezesRemaining: 0,
            updatedAt: Date()
        )

        try persistence.saveCurrentStreakData(streakId: "test", testData)
        let retrieved = persistence.getSavedStreakData(streakId: "test")

        #expect(retrieved?.streakId == "test")
        #expect(retrieved?.currentStreak == 0)
        #expect(retrieved?.longestStreak == 0)
        #expect(retrieved?.totalEvents == 0)
        #expect(retrieved?.freezesRemaining == 0)

        // Clean up
        try persistence.saveCurrentStreakData(streakId: "test", nil)
    }

    @Test("Save and retrieve large values")
    func saveLargeValues() async throws {
        let persistence = FileManagerStreakPersistence()

        let testData = CurrentStreakData(
            streakId: "test",
            currentStreak: 999,
            longestStreak: 1000,
            lastEventDate: Date(),
            streakStartDate: Date(),
            totalEvents: 5000,
            freezesRemaining: 100,
            updatedAt: Date()
        )

        try persistence.saveCurrentStreakData(streakId: "test", testData)
        let retrieved = persistence.getSavedStreakData(streakId: "test")

        #expect(retrieved?.streakId == "test")
        #expect(retrieved?.currentStreak == 999)
        #expect(retrieved?.longestStreak == 1000)
        #expect(retrieved?.totalEvents == 5000)
        #expect(retrieved?.freezesRemaining == 100)

        // Clean up
        try persistence.saveCurrentStreakData(streakId: "test", nil)
    }

    @Test("Retrieve after clearing returns nil")
    func retrieveAfterClearingReturnsNil() async throws {
        let persistence = FileManagerStreakPersistence()

        // Save data
        let testData = CurrentStreakData(
            streakId: "test",
            currentStreak: 5,
            longestStreak: 10,
            lastEventDate: Date(),
            streakStartDate: Date(),
            freezesRemaining: 2,
            updatedAt: Date()
        )
        try persistence.saveCurrentStreakData(streakId: "test", testData)

        // Clear
        try persistence.saveCurrentStreakData(streakId: "test", nil)

        // Retrieve should return nil
        #expect(persistence.getSavedStreakData(streakId: "test") == nil)
    }

    @Test("Different streakIds store data separately")
    func differentStreakIdsStoreSeparately() async throws {
        let persistence = FileManagerStreakPersistence()

        // Save data for "workout" streak
        let workoutData = CurrentStreakData(
            streakId: "workout",
            currentStreak: 5,
            longestStreak: 10,
            lastEventDate: Date(),
            streakStartDate: Date(),
            freezesRemaining: 2,
            updatedAt: Date()
        )
        try persistence.saveCurrentStreakData(streakId: "workout", workoutData)

        // Save data for "reading" streak
        let readingData = CurrentStreakData(
            streakId: "reading",
            currentStreak: 7,
            longestStreak: 12,
            lastEventDate: Date(),
            streakStartDate: Date(),
            freezesRemaining: 3,
            updatedAt: Date()
        )
        try persistence.saveCurrentStreakData(streakId: "reading", readingData)

        // Retrieve both and verify they're separate
        let retrievedWorkout = persistence.getSavedStreakData(streakId: "workout")
        let retrievedReading = persistence.getSavedStreakData(streakId: "reading")

        #expect(retrievedWorkout?.streakId == "workout")
        #expect(retrievedWorkout?.currentStreak == 5)
        #expect(retrievedWorkout?.longestStreak == 10)

        #expect(retrievedReading?.streakId == "reading")
        #expect(retrievedReading?.currentStreak == 7)
        #expect(retrievedReading?.longestStreak == 12)

        // Clean up both
        try persistence.saveCurrentStreakData(streakId: "workout", nil)
        try persistence.saveCurrentStreakData(streakId: "reading", nil)
    }
}
