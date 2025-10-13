//
//  MockLocalExperiencePointsPersistenceTests.swift
//  SwiftfulGamificationTests
//
//  Tests for MockLocalExperiencePointsPersistence
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("MockLocalExperiencePointsPersistence Tests")
@MainActor
struct MockLocalExperiencePointsPersistenceTests {

    // MARK: - Initialization Tests

    @Test("Initializes with provided XP data")
    func testInitializesWithProvidedData() throws {
        // Given: XP data
        let data = CurrentExperiencePointsData.mock(pointsToday: 5000)

        // When: Initializing persistence with data
        let persistence = MockLocalExperiencePointsPersistence(data: data)

        // Then: Should store the data
        let saved = persistence.getSavedExperiencePointsData(experienceKey: data.experienceKey)
        #expect(saved == data)
    }

    // MARK: - getSavedExperiencePointsData Tests

    @Test("getSavedExperiencePointsData returns initial data")
    func testGetSavedExperiencePointsDataReturnsInitial() throws {
        // Given: Persistence initialized with data
        let initialData = CurrentExperiencePointsData.mock(pointsToday: 7000)
        let persistence = MockLocalExperiencePointsPersistence(data: initialData)

        // When: Getting saved data
        let saved = persistence.getSavedExperiencePointsData(experienceKey: initialData.experienceKey)

        // Then: Should return initial data
        #expect(saved == initialData)
    }

    @Test("getSavedExperiencePointsData returns updated data after save")
    func testGetSavedExperiencePointsDataReturnsUpdated() throws {
        // Given: Persistence with initial data
        let initialData = CurrentExperiencePointsData.mock(pointsToday: 5000)
        let persistence = MockLocalExperiencePointsPersistence(data: initialData)

        // When: Saving new data
        let newData = CurrentExperiencePointsData.mock(pointsToday: 10000)
        try persistence.saveCurrentExperiencePointsData(experienceKey: newData.experienceKey, newData)

        // Then: Should return new data
        let saved = persistence.getSavedExperiencePointsData(experienceKey: newData.experienceKey)
        #expect(saved == newData)
        #expect(saved?.pointsToday == 10000)
    }

    // MARK: - saveExperiencePointsData Tests

    @Test("saveExperiencePointsData persists new data")
    func testSaveExperiencePointsDataPersists() throws {
        // Given: Persistence with blank data
        let blank = CurrentExperiencePointsData.blank(experienceKey: "test")
        let persistence = MockLocalExperiencePointsPersistence(data: blank)

        // When: Saving new XP data
        let newData = CurrentExperiencePointsData.mock(pointsToday: 15000)
        try persistence.saveCurrentExperiencePointsData(experienceKey: newData.experienceKey, newData)

        // Then: New data should be persisted
        let saved = persistence.getSavedExperiencePointsData(experienceKey: newData.experienceKey)
        #expect(saved == newData)
    }

    @Test("saveExperiencePointsData overwrites previous data")
    func testSaveExperiencePointsDataOverwrites() throws {
        // Given: Persistence with initial data
        let initial = CurrentExperiencePointsData.mock(pointsToday: 5000)
        let persistence = MockLocalExperiencePointsPersistence(data: initial)

        // When: Saving multiple times
        let data1 = CurrentExperiencePointsData.mock(pointsToday: 10000)
        try persistence.saveCurrentExperiencePointsData(experienceKey: data1.experienceKey, data1)

        let data2 = CurrentExperiencePointsData.mock(pointsToday: 20000)
        try persistence.saveCurrentExperiencePointsData(experienceKey: data2.experienceKey, data2)

        // Then: Only last data should be saved
        let saved = persistence.getSavedExperiencePointsData(experienceKey: data2.experienceKey)
        #expect(saved == data2)
        #expect(saved?.pointsToday == 20000)
    }

    @Test("saveExperiencePointsData with nil clears data")
    func testSaveExperiencePointsDataWithNil() throws {
        // Given: Persistence with initial data
        let initial = CurrentExperiencePointsData.mock(pointsToday: 5000)
        let persistence = MockLocalExperiencePointsPersistence(data: initial)

        // When: Saving nil
        try persistence.saveCurrentExperiencePointsData(experienceKey: initial.experienceKey, nil)

        // Then: Should be cleared
        let saved = persistence.getSavedExperiencePointsData(experienceKey: initial.experienceKey)
        #expect(saved == nil)
    }

    // MARK: - Persistence Tests

    @Test("Multiple saves preserve last value")
    func testMultipleSavesPreserveLast() throws {
        // Given: Persistence with blank data
        let blank = CurrentExperiencePointsData.blank(experienceKey: "main")
        let persistence = MockLocalExperiencePointsPersistence(data: blank)

        // When: Saving multiple data objects (all with same default "main" experienceId)
        for i in 1...5 {
            let data = CurrentExperiencePointsData.mock(pointsToday: i * 1000)
            try persistence.saveCurrentExperiencePointsData(experienceKey: data.experienceKey, data)
        }

        // Then: Last data should be saved (they all have same "main" experienceId from mock)
        let saved = persistence.getSavedExperiencePointsData(experienceKey: "main")
        #expect(saved?.pointsToday == 5000)
    }

    @Test("Saved data persists across get calls")
    func testSavedDataPersistsAcrossGets() throws {
        // Given: Persistence with saved data
        let data = CurrentExperiencePointsData.mock(pointsToday: 12000)
        let persistence = MockLocalExperiencePointsPersistence(data: data)

        // When: Getting saved data multiple times
        let get1 = persistence.getSavedExperiencePointsData(experienceKey: data.experienceKey)
        let get2 = persistence.getSavedExperiencePointsData(experienceKey: data.experienceKey)
        let get3 = persistence.getSavedExperiencePointsData(experienceKey: data.experienceKey)

        // Then: All should return same data
        #expect(get1 == data)
        #expect(get2 == data)
        #expect(get3 == data)
    }

    // MARK: - State Management Tests

    @Test("Save and get maintain data consistency")
    func testSaveAndGetConsistency() throws {
        // Given: Persistence
        let blank = CurrentExperiencePointsData.blank(experienceKey: "test")
        let persistence = MockLocalExperiencePointsPersistence(data: blank)

        // When: Performing multiple save/get cycles
        let data1 = CurrentExperiencePointsData.mock(pointsToday: 3000)
        try persistence.saveCurrentExperiencePointsData(experienceKey: data1.experienceKey, data1)
        let saved1 = persistence.getSavedExperiencePointsData(experienceKey: data1.experienceKey)

        let data2 = CurrentExperiencePointsData.mock(pointsToday: 7000)
        try persistence.saveCurrentExperiencePointsData(experienceKey: data2.experienceKey, data2)
        let saved2 = persistence.getSavedExperiencePointsData(experienceKey: data2.experienceKey)

        // Then: Each get should return correct data
        #expect(saved1 == data1)
        #expect(saved2 == data2)
    }

    @Test("Different experience IDs are stored separately")
    func testDifferentExperienceIds() throws {
        // Given: Persistence with main XP data
        let mainData = CurrentExperiencePointsData.blank(experienceKey: "main")
        let persistence = MockLocalExperiencePointsPersistence(data: mainData)

        // When: Saving battle XP data
        let battleData = CurrentExperiencePointsData.blank(experienceKey: "battle")
        try persistence.saveCurrentExperiencePointsData(experienceKey: battleData.experienceKey, battleData)

        // Then: Both should be saved separately
        let savedMain = persistence.getSavedExperiencePointsData(experienceKey: "main")
        let savedBattle = persistence.getSavedExperiencePointsData(experienceKey: "battle")

        #expect(savedMain?.experienceKey == "main")
        #expect(savedBattle?.experienceKey == "battle")
    }

    @Test("Complex XP data is preserved")
    func testComplexDataPreservation() throws {
        // Given: Persistence
        let blank = CurrentExperiencePointsData.blank(experienceKey: "test")
        let persistence = MockLocalExperiencePointsPersistence(data: blank)

        // When: Saving complex data with all fields
        let complexData = CurrentExperiencePointsData(
            experienceKey: "complex",
            pointsToday: 250000,
            eventsTodayCount: 5000,
            createdAt: Date().addingTimeInterval(-86400 * 60),
            updatedAt: Date()
        )
        try persistence.saveCurrentExperiencePointsData(experienceKey: complexData.experienceKey, complexData)

        // Then: All fields should be preserved
        let saved = persistence.getSavedExperiencePointsData(experienceKey: complexData.experienceKey)
        #expect(saved == complexData)
        #expect(saved?.pointsToday == 250000)
        #expect(saved?.eventsTodayCount == 5000)
    }

    @Test("Blank data can be saved and retrieved")
    func testBlankDataSaveRetrieve() throws {
        // Given: Persistence with active data
        let activeData = CurrentExperiencePointsData.mock(pointsToday: 10000)
        let persistence = MockLocalExperiencePointsPersistence(data: activeData)

        // When: Saving blank data
        let blank = CurrentExperiencePointsData.blank(experienceKey: "main")
        try persistence.saveCurrentExperiencePointsData(experienceKey: blank.experienceKey, blank)

        // Then: Blank data should be saved
        let saved = persistence.getSavedExperiencePointsData(experienceKey: blank.experienceKey)
        #expect(saved == blank)
        #expect(saved?.pointsToday == 0)
        #expect(saved?.eventsTodayCount == 0)
    }
}
