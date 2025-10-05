//
//  MockRemoteProgressServiceTests.swift
//  SwiftfulGamificationTests
//
//  Tests for MockRemoteProgressService
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("MockRemoteProgressService Tests")
@MainActor
struct MockRemoteProgressServiceTests {

    // MARK: - Initialization Tests

    @Test("Service initializes with empty items by default")
    func testInitializationEmpty() async throws {
        // When: Creating service with no items
        let service = MockRemoteProgressService()

        // Then: Should return empty array
        let items = try await service.getAllProgressItems(userId: "user123")
        #expect(items.isEmpty)
    }

    @Test("Service initializes with provided items")
    func testInitializationWithItems() async throws {
        // Given: Initial items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]

        // When: Creating service with items
        let service = MockRemoteProgressService(items: items)

        // Then: Should return all items
        let retrieved = try await service.getAllProgressItems(userId: "user123")
        #expect(retrieved.count == 2)
        #expect(retrieved.contains(where: { $0.id == "item1" }))
        #expect(retrieved.contains(where: { $0.id == "item2" }))
    }

    // MARK: - Get All Items Tests

    @Test("getAllProgressItems returns all items")
    func testGetAllProgressItems() async throws {
        // Given: Service with multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.1),
            ProgressItem.mock(id: "item2", value: 0.5),
            ProgressItem.mock(id: "item3", value: 0.9)
        ]
        let service = MockRemoteProgressService(items: items)

        // When: Getting all items
        let retrieved = try await service.getAllProgressItems(userId: "user123")

        // Then: Should return all items
        #expect(retrieved.count == 3)
    }

    @Test("getAllProgressItems works with different userIds")
    func testGetAllProgressItemsDifferentUsers() async throws {
        // Given: Service with items
        let service = MockRemoteProgressService(items: [ProgressItem.mock()])

        // When: Getting items for different users
        let user1Items = try await service.getAllProgressItems(userId: "user1")
        let user2Items = try await service.getAllProgressItems(userId: "user2")

        // Then: Should return same items (mock doesn't separate by user)
        #expect(user1Items.count == user2Items.count)
    }

    // MARK: - Update Progress Tests

    @Test("updateProgress adds new item")
    func testUpdateProgressAddsNewItem() async throws {
        // Given: Service with no items
        let service = MockRemoteProgressService()

        // When: Updating progress for new item
        let item = ProgressItem.mock(id: "new_item", value: 0.6)
        try await service.updateProgress(userId: "user123", item: item)

        // Then: Should add the item
        let items = try await service.getAllProgressItems(userId: "user123")
        #expect(items.count == 1)
        #expect(items.first?.id == "new_item")
        #expect(items.first?.value == 0.6)
    }

    @Test("updateProgress updates existing item")
    func testUpdateProgressUpdatesExisting() async throws {
        // Given: Service with existing item
        let original = ProgressItem.mock(id: "item1", value: 0.3)
        let service = MockRemoteProgressService(items: [original])

        // When: Updating the same item with new value
        let updated = ProgressItem(id: "item1", value: 0.8)
        try await service.updateProgress(userId: "user123", item: updated)

        // Then: Should update the value
        let items = try await service.getAllProgressItems(userId: "user123")
        #expect(items.count == 1)
        #expect(items.first?.id == "item1")
        #expect(items.first?.value == 0.8)
    }

    @Test("updateProgress updates dates")
    func testUpdateProgressUpdatesDates() async throws {
        // Given: Service with existing item
        let original = ProgressItem.mock(id: "item1", value: 0.3)
        let service = MockRemoteProgressService(items: [original])

        // When: Updating with new dates
        let newDateModified = Date()
        let updated = ProgressItem(
            id: "item1",
            value: 0.5,
            dateCreated: original.dateCreated,
            dateModified: newDateModified
        )
        try await service.updateProgress(userId: "user123", item: updated)

        // Then: Should update the modified date
        let items = try await service.getAllProgressItems(userId: "user123")
        #expect(items.first?.dateModified == newDateModified)
    }

    // MARK: - Delete Progress Tests

    @Test("deleteProgress removes item")
    func testDeleteProgressRemovesItem() async throws {
        // Given: Service with items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]
        let service = MockRemoteProgressService(items: items)

        // When: Deleting one item
        try await service.deleteProgress(userId: "user123", id: "item1")

        // Then: Should remove only that item
        let remaining = try await service.getAllProgressItems(userId: "user123")
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == "item2")
    }

    @Test("deleteProgress handles non-existent item")
    func testDeleteProgressNonExistent() async throws {
        // Given: Service with items
        let service = MockRemoteProgressService(items: [ProgressItem.mock(id: "item1")])

        // When: Deleting non-existent item
        try await service.deleteProgress(userId: "user123", id: "non_existent")

        // Then: Should not throw and keep existing items
        let items = try await service.getAllProgressItems(userId: "user123")
        #expect(items.count == 1)
    }

    // MARK: - Delete All Progress Tests

    @Test("deleteAllProgress removes all items")
    func testDeleteAllProgressRemovesAll() async throws {
        // Given: Service with multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.1),
            ProgressItem.mock(id: "item2", value: 0.5),
            ProgressItem.mock(id: "item3", value: 0.9)
        ]
        let service = MockRemoteProgressService(items: items)

        // When: Deleting all items
        try await service.deleteAllProgress(userId: "user123")

        // Then: Should remove all items
        let remaining = try await service.getAllProgressItems(userId: "user123")
        #expect(remaining.isEmpty)
    }

    @Test("deleteAllProgress handles empty service")
    func testDeleteAllProgressEmpty() async throws {
        // Given: Service with no items
        let service = MockRemoteProgressService()

        // When: Deleting all items
        try await service.deleteAllProgress(userId: "user123")

        // Then: Should not throw
        let items = try await service.getAllProgressItems(userId: "user123")
        #expect(items.isEmpty)
    }

    // MARK: - Stream Tests

    @Test("streamProgressUpdates emits updates when item changes")
    func testStreamEmitsUpdates() async throws {
        // Given: Service with initial items
        let service = MockRemoteProgressService(items: [ProgressItem.mock(id: "item1", value: 0.5)])

        // When: Starting stream and updating item
        var receivedItems: [ProgressItem] = []
        let streamTask = Task {
            for try await item in service.streamProgressUpdates(userId: "user123") {
                receivedItems.append(item)
                if receivedItems.count >= 2 {
                    break
                }
            }
        }

        // Give stream time to start
        try await Task.sleep(nanoseconds: 50_000_000)

        // Update item
        try await service.updateProgress(userId: "user123", item: ProgressItem(id: "item1", value: 0.8))

        // Wait for stream to receive update
        try await Task.sleep(nanoseconds: 100_000_000)

        streamTask.cancel()

        // Then: Should have received updates
        #expect(receivedItems.count >= 1)
    }
}
