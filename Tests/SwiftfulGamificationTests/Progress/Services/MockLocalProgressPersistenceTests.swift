//
//  MockLocalProgressPersistenceTests.swift
//  SwiftfulGamificationTests
//
//  Tests for MockLocalProgressPersistence
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("MockLocalProgressPersistence Tests")
@MainActor
struct MockLocalProgressPersistenceTests {

    // MARK: - Initialization Tests

    @Test("Persistence initializes with empty items by default")
    func testInitializationEmpty() throws {
        // When: Creating persistence with no items
        let persistence = MockLocalProgressPersistence()

        // Then: Should return empty array
        let items = persistence.getAllProgressItems(progressKey: "default")
        #expect(items.isEmpty)
    }

    @Test("Persistence initializes with provided items")
    func testInitializationWithItems() throws {
        // Given: Initial items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]

        // When: Creating persistence with items
        let persistence = MockLocalProgressPersistence(items: items)

        // Then: Should return all items
        let retrieved = persistence.getAllProgressItems(progressKey: "default")
        #expect(retrieved.count == 2)
        #expect(retrieved.contains(where: { $0.id == "item1" }))
        #expect(retrieved.contains(where: { $0.id == "item2" }))
    }

    // MARK: - Get Item Tests

    @Test("getProgressItem returns item by id")
    func testGetProgressItemReturnsItem() throws {
        // Given: Persistence with items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]
        let persistence = MockLocalProgressPersistence(items: items)

        // When: Getting item by id
        let item = persistence.getProgressItem(progressKey: "default", id: "item1")

        // Then: Should return correct item
        #expect(item?.id == "item1")
        #expect(item?.value == 0.3)
    }

    @Test("getProgressItem returns nil for non-existent id")
    func testGetProgressItemReturnsNil() throws {
        // Given: Persistence with items
        let persistence = MockLocalProgressPersistence(items: [ProgressItem.mock(id: "item1")])

        // When: Getting non-existent item
        let item = persistence.getProgressItem(progressKey: "default", id: "non_existent")

        // Then: Should return nil
        #expect(item == nil)
    }

    // MARK: - Get All Items Tests

    @Test("getAllProgressItems returns all items")
    func testGetAllProgressItems() throws {
        // Given: Persistence with multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.1),
            ProgressItem.mock(id: "item2", value: 0.5),
            ProgressItem.mock(id: "item3", value: 0.9)
        ]
        let persistence = MockLocalProgressPersistence(items: items)

        // When: Getting all items
        let retrieved = persistence.getAllProgressItems(progressKey: "default")

        // Then: Should return all items
        #expect(retrieved.count == 3)
    }

    @Test("getAllProgressItems returns empty array when no items")
    func testGetAllProgressItemsEmpty() throws {
        // Given: Empty persistence
        let persistence = MockLocalProgressPersistence()

        // When: Getting all items
        let items = persistence.getAllProgressItems(progressKey: "default")

        // Then: Should return empty array
        #expect(items.isEmpty)
    }

    // MARK: - Save Item Tests

    @Test("saveProgressItem adds new item")
    func testSaveProgressItemAddsNew() throws {
        // Given: Empty persistence
        let persistence = MockLocalProgressPersistence()

        // When: Saving new item
        let item = ProgressItem.mock(id: "new_item", value: 0.6)
        try persistence.saveProgressItem(item)

        // Then: Should add the item
        let items = persistence.getAllProgressItems(progressKey: "default")
        #expect(items.count == 1)
        #expect(items.first?.id == "new_item")
        #expect(items.first?.value == 0.6)
    }

    @Test("saveProgressItem updates existing item")
    func testSaveProgressItemUpdatesExisting() throws {
        // Given: Persistence with existing item
        let original = ProgressItem.mock(id: "item1", value: 0.3)
        let persistence = MockLocalProgressPersistence(items: [original])

        // When: Saving item with same id but different value
        let updated = ProgressItem(id: "item1", progressKey: "default", value: 0.8)
        try persistence.saveProgressItem(updated)

        // Then: Should update the value
        let items = persistence.getAllProgressItems(progressKey: "default")
        #expect(items.count == 1)
        #expect(items.first?.value == 0.8)
    }

    // MARK: - Save Multiple Items Tests

    @Test("saveProgressItems adds multiple new items")
    func testSaveProgressItemsAddsMultiple() throws {
        // Given: Empty persistence
        let persistence = MockLocalProgressPersistence()

        // When: Saving multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]
        try persistence.saveProgressItems(items)

        // Then: Should add all items
        let saved = persistence.getAllProgressItems(progressKey: "default")
        #expect(saved.count == 2)
    }

    @Test("saveProgressItems updates existing and adds new")
    func testSaveProgressItemsMixed() throws {
        // Given: Persistence with one item
        let original = ProgressItem.mock(id: "item1", value: 0.3)
        let persistence = MockLocalProgressPersistence(items: [original])

        // When: Saving batch with one update and one new item
        let items = [
            ProgressItem(id: "item1", progressKey: "default", value: 0.8),
            ProgressItem.mock(id: "item2", value: 0.5)
        ]
        try persistence.saveProgressItems(items)

        // Then: Should have both items with correct values
        let saved = persistence.getAllProgressItems(progressKey: "default")
        #expect(saved.count == 2)
        #expect(saved.first(where: { $0.id == "item1" })?.value == 0.8)
        #expect(saved.first(where: { $0.id == "item2" })?.value == 0.5)
    }

    @Test("saveProgressItems handles empty array")
    func testSaveProgressItemsEmpty() throws {
        // Given: Persistence with items
        let persistence = MockLocalProgressPersistence(items: [ProgressItem.mock(id: "item1")])

        // When: Saving empty array
        try persistence.saveProgressItems([])

        // Then: Should not affect existing items
        let items = persistence.getAllProgressItems(progressKey: "default")
        #expect(items.count == 1)
    }

    // MARK: - Delete Item Tests

    @Test("deleteProgressItem removes item")
    func testDeleteProgressItemRemoves() throws {
        // Given: Persistence with items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]
        let persistence = MockLocalProgressPersistence(items: items)

        // When: Deleting one item
        try persistence.deleteProgressItem(progressKey: "default", id: "item1")

        // Then: Should remove only that item
        let remaining = persistence.getAllProgressItems(progressKey: "default")
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == "item2")
    }

    @Test("deleteProgressItem handles non-existent id")
    func testDeleteProgressItemNonExistent() throws {
        // Given: Persistence with items
        let persistence = MockLocalProgressPersistence(items: [ProgressItem.mock(id: "item1")])

        // When: Deleting non-existent item
        try persistence.deleteProgressItem(progressKey: "default", id: "non_existent")

        // Then: Should not throw and keep existing items
        let items = persistence.getAllProgressItems(progressKey: "default")
        #expect(items.count == 1)
    }

    // MARK: - Delete All Tests

    @Test("deleteAllProgressItems removes all")
    func testDeleteAllProgressItemsRemovesAll() throws {
        // Given: Persistence with multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.1),
            ProgressItem.mock(id: "item2", value: 0.5),
            ProgressItem.mock(id: "item3", value: 0.9)
        ]
        let persistence = MockLocalProgressPersistence(items: items)

        // When: Deleting all items
        try persistence.deleteAllProgressItems(progressKey: "default")

        // Then: Should remove all items
        let remaining = persistence.getAllProgressItems(progressKey: "default")
        #expect(remaining.isEmpty)
    }

    @Test("deleteAllProgressItems handles empty persistence")
    func testDeleteAllProgressItemsEmpty() throws {
        // Given: Empty persistence
        let persistence = MockLocalProgressPersistence()

        // When: Deleting all items
        try persistence.deleteAllProgressItems(progressKey: "default")

        // Then: Should not throw
        let items = persistence.getAllProgressItems(progressKey: "default")
        #expect(items.isEmpty)
    }

    // MARK: - ProgressKey Filtering Tests

    @Test("getAllProgressItems filters by progressKey")
    func testGetAllProgressItemsFiltersByProgressKey() throws {
        // Given: Persistence with items from different progressKeys
        let items = [
            ProgressItem(id: "item1", progressKey: "world_1", value: 0.3),
            ProgressItem(id: "item2", progressKey: "world_1", value: 0.7),
            ProgressItem(id: "item3", progressKey: "world_2", value: 0.5),
            ProgressItem(id: "item4", progressKey: "world_2", value: 0.9)
        ]
        let persistence = MockLocalProgressPersistence(items: items)

        // When: Getting items for specific progressKey
        let world1Items = persistence.getAllProgressItems(progressKey: "world_1")
        let world2Items = persistence.getAllProgressItems(progressKey: "world_2")

        // Then: Should return only items for that progressKey
        #expect(world1Items.count == 2)
        #expect(world1Items.allSatisfy { $0.progressKey == "world_1" })
        #expect(world2Items.count == 2)
        #expect(world2Items.allSatisfy { $0.progressKey == "world_2" })
    }

    @Test("Items with same id but different progressKey are separate")
    func testSameIdDifferentProgressKeyAreSeparate() throws {
        // Given: Persistence with items having same id but different progressKeys
        let items = [
            ProgressItem(id: "level_1", progressKey: "world_1", value: 0.5),
            ProgressItem(id: "level_1", progressKey: "world_2", value: 0.8)
        ]
        let persistence = MockLocalProgressPersistence(items: items)

        // When: Getting items for each progressKey
        let world1Item = persistence.getProgressItem(progressKey: "world_1", id: "level_1")
        let world2Item = persistence.getProgressItem(progressKey: "world_2", id: "level_1")

        // Then: Should return different items
        #expect(world1Item?.value == 0.5)
        #expect(world2Item?.value == 0.8)
        #expect(world1Item?.compositeId == "world_1_level_1")
        #expect(world2Item?.compositeId == "world_2_level_1")
    }

    @Test("deleteAllProgressItems only deletes items for specified progressKey")
    func testDeleteAllProgressItemsFiltersByProgressKey() throws {
        // Given: Persistence with items from different progressKeys
        let items = [
            ProgressItem(id: "item1", progressKey: "world_1", value: 0.3),
            ProgressItem(id: "item2", progressKey: "world_2", value: 0.7)
        ]
        let persistence = MockLocalProgressPersistence(items: items)

        // When: Deleting all items for world_1
        try persistence.deleteAllProgressItems(progressKey: "world_1")

        // Then: Should only delete world_1 items
        let world1Items = persistence.getAllProgressItems(progressKey: "world_1")
        let world2Items = persistence.getAllProgressItems(progressKey: "world_2")
        #expect(world1Items.isEmpty)
        #expect(world2Items.count == 1)
    }
}
