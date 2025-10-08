//
//  MockLocalStreakPersistenceTests.swift
//  SwiftfulGamificationTests
//
//  Tests for MockLocalStreakPersistence
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("MockLocalStreakPersistence Tests")
@MainActor
struct MockLocalStreakPersistenceTests {

    // MARK: - Initialization Tests

    @Test("Initializes with provided streak data")
    func testInitializesWithProvidedStreak() throws {
        // Given: A streak
        let streak = CurrentStreakData.mock(currentStreak: 5)

        // When: Initializing persistence with streak
        let persistence = MockLocalStreakPersistence(streak: streak)

        // Then: Should store the streak
        let saved = persistence.getSavedStreakData(streakKey: streak.streakKey)
        #expect(saved == streak)
    }

    // MARK: - getSavedStreakData Tests

    @Test("getSavedStreakData returns initial streak")
    func testGetSavedStreakDataReturnsInitial() throws {
        // Given: Persistence initialized with streak
        let initialStreak = CurrentStreakData.mock(currentStreak: 7)
        let persistence = MockLocalStreakPersistence(streak: initialStreak)

        // When: Getting saved streak
        let saved = persistence.getSavedStreakData(streakKey: initialStreak.streakKey)

        // Then: Should return initial streak
        #expect(saved == initialStreak)
    }

    @Test("getSavedStreakData returns updated streak after save")
    func testGetSavedStreakDataReturnsUpdated() throws {
        // Given: Persistence with initial streak
        let initialStreak = CurrentStreakData.mock(currentStreak: 5)
        let persistence = MockLocalStreakPersistence(streak: initialStreak)

        // When: Saving new streak
        let newStreak = CurrentStreakData.mock(currentStreak: 10)
        try persistence.saveCurrentStreakData(streakKey: newStreak.streakKey, newStreak)

        // Then: Should return new streak
        let saved = persistence.getSavedStreakData(streakKey: newStreak.streakKey)
        #expect(saved == newStreak)
        #expect(saved?.currentStreak == 10)
    }

    // MARK: - saveStreakData Tests

    @Test("saveStreakData persists new streak")
    func testSaveStreakDataPersists() throws {
        // Given: Persistence with blank streak
        let blank = CurrentStreakData.blank(streakKey: "test")
        let persistence = MockLocalStreakPersistence(streak: blank)

        // When: Saving new streak data
        let newStreak = CurrentStreakData.mock(currentStreak: 15)
        try persistence.saveCurrentStreakData(streakKey: newStreak.streakKey, newStreak)

        // Then: New streak should be persisted
        let saved = persistence.getSavedStreakData(streakKey: newStreak.streakKey)
        #expect(saved == newStreak)
    }

    @Test("saveStreakData overwrites previous streak")
    func testSaveStreakDataOverwrites() throws {
        // Given: Persistence with initial streak
        let initial = CurrentStreakData.mock(currentStreak: 5)
        let persistence = MockLocalStreakPersistence(streak: initial)

        // When: Saving multiple times
        let streak1 = CurrentStreakData.mock(currentStreak: 10)
        try persistence.saveCurrentStreakData(streakKey: streak1.streakKey, streak1)

        let streak2 = CurrentStreakData.mock(currentStreak: 20)
        try persistence.saveCurrentStreakData(streakKey: streak2.streakKey, streak2)

        // Then: Only last streak should be saved
        let saved = persistence.getSavedStreakData(streakKey: streak2.streakKey)
        #expect(saved == streak2)
        #expect(saved?.currentStreak == 20)
    }

    @Test("saveStreakData with nil clears data")
    func testSaveStreakDataWithNil() throws {
        // Given: Persistence with initial streak
        let initial = CurrentStreakData.mock(currentStreak: 5)
        let persistence = MockLocalStreakPersistence(streak: initial)

        // When: Saving nil
        try persistence.saveCurrentStreakData(streakKey: initial.streakKey, nil)

        // Then: Should be cleared
        let saved = persistence.getSavedStreakData(streakKey: initial.streakKey)
        #expect(saved == nil)
    }

    // MARK: - Persistence Tests

    @Test("Multiple saves preserve last value")
    func testMultipleSavesPreserveLast() throws {
        // Given: Persistence with blank streak
        let blank = CurrentStreakData.blank(streakKey: "workout")
        let persistence = MockLocalStreakPersistence(streak: blank)

        // When: Saving multiple streaks (all with same default "workout" streakId)
        for i in 1...5 {
            let streak = CurrentStreakData.mock(currentStreak: i)
            try persistence.saveCurrentStreakData(streakKey: streak.streakKey, streak)
        }

        // Then: Last streak should be saved (they all have same "workout" streakId from mock)
        let saved = persistence.getSavedStreakData(streakKey: "workout")
        #expect(saved?.currentStreak == 5)
    }

    @Test("Saved data persists across get calls")
    func testSavedDataPersistsAcrossGets() throws {
        // Given: Persistence with saved streak
        let streak = CurrentStreakData.mock(currentStreak: 12)
        let persistence = MockLocalStreakPersistence(streak: streak)

        // When: Getting saved data multiple times
        let get1 = persistence.getSavedStreakData(streakKey: streak.streakKey)
        let get2 = persistence.getSavedStreakData(streakKey: streak.streakKey)
        let get3 = persistence.getSavedStreakData(streakKey: streak.streakKey)

        // Then: All should return same data
        #expect(get1 == streak)
        #expect(get2 == streak)
        #expect(get3 == streak)
    }

    // MARK: - State Management Tests

    @Test("Save and get maintain data consistency")
    func testSaveAndGetConsistency() throws {
        // Given: Persistence
        let blank = CurrentStreakData.blank(streakKey: "test")
        let persistence = MockLocalStreakPersistence(streak: blank)

        // When: Performing multiple save/get cycles
        let streak1 = CurrentStreakData.mock(currentStreak: 3)
        try persistence.saveCurrentStreakData(streakKey: streak1.streakKey, streak1)
        let saved1 = persistence.getSavedStreakData(streakKey: streak1.streakKey)

        let streak2 = CurrentStreakData.mock(currentStreak: 7)
        try persistence.saveCurrentStreakData(streakKey: streak2.streakKey, streak2)
        let saved2 = persistence.getSavedStreakData(streakKey: streak2.streakKey)

        // Then: Each get should return correct streak
        #expect(saved1 == streak1)
        #expect(saved2 == streak2)
    }

    @Test("Different streak IDs are stored separately")
    func testDifferentStreakIds() throws {
        // Given: Persistence with workout streak
        let workoutStreak = CurrentStreakData.blank(streakKey: "workout")
        let persistence = MockLocalStreakPersistence(streak: workoutStreak)

        // When: Saving reading streak
        let readingStreak = CurrentStreakData.blank(streakKey: "reading")
        try persistence.saveCurrentStreakData(streakKey: readingStreak.streakKey, readingStreak)

        // Then: Both should be saved separately
        let savedWorkout = persistence.getSavedStreakData(streakKey: "workout")
        let savedReading = persistence.getSavedStreakData(streakKey: "reading")

        #expect(savedWorkout?.streakKey == "workout")
        #expect(savedReading?.streakKey == "reading")
    }

    @Test("Complex streak data is preserved")
    func testComplexStreakPreservation() throws {
        // Given: Persistence
        let blank = CurrentStreakData.blank(streakKey: "test")
        let persistence = MockLocalStreakPersistence(streak: blank)

        // When: Saving complex streak with all fields
        let complexStreak = CurrentStreakData(
            streakKey: "complex",
            currentStreak: 25,
            longestStreak: 50,
            lastEventDate: Date(),
            lastEventTimezone: "America/New_York",
            streakStartDate: Date().addingTimeInterval(-86400 * 25),
            totalEvents: 100,
            freezesRemaining: 5,
            createdAt: Date().addingTimeInterval(-86400 * 60),
            updatedAt: Date(),
            eventsRequiredPerDay: 3,
            todayEventCount: 2
        )
        try persistence.saveCurrentStreakData(streakKey: complexStreak.streakKey, complexStreak)

        // Then: All fields should be preserved
        let saved = persistence.getSavedStreakData(streakKey: complexStreak.streakKey)
        #expect(saved == complexStreak)
        #expect(saved?.currentStreak == 25)
        #expect(saved?.longestStreak == 50)
        #expect(saved?.totalEvents == 100)
        #expect(saved?.eventsRequiredPerDay == 3)
    }

    @Test("Blank streak can be saved and retrieved")
    func testBlankStreakSaveRetrieve() throws {
        // Given: Persistence with active streak
        let activeStreak = CurrentStreakData.mockActive()
        let persistence = MockLocalStreakPersistence(streak: activeStreak)

        // When: Saving blank streak
        let blank = CurrentStreakData.blank(streakKey: "workout")
        try persistence.saveCurrentStreakData(streakKey: blank.streakKey, blank)

        // Then: Blank streak should be saved
        let saved = persistence.getSavedStreakData(streakKey: blank.streakKey)
        #expect(saved == blank)
        #expect(saved?.currentStreak == 0)
        #expect(saved?.longestStreak == 0)
    }
}
