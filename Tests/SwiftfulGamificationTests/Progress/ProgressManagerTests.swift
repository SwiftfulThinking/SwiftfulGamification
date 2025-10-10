//
//  ProgressManagerTests.swift
//  SwiftfulGamificationTests
//
//  Comprehensive integration tests for ProgressManager
//

import Testing
import Foundation
@testable import SwiftfulGamification

// MARK: - Test Suite

@Suite("ProgressManager Tests")
@MainActor
struct ProgressManagerTests {

    // MARK: - Initialization Tests

    @Test("Manager initializes with empty cache when local storage is empty")
    func testInitializationEmpty() throws {
        // Given: Empty local storage
        let services = MockProgressServices(items: [])

        // When: Initializing manager
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Then: Should have empty cache
        #expect(manager.getProgress(id: "any_id") == 0.0)
    }

    @Test("Manager initializes and loads cached items asynchronously")
    func testInitializationWithLocalCache() async throws {
        // Given: Local storage with saved items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]
        let services = MockProgressServices(items: items)

        // When: Initializing manager
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to complete
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should load items into cache from local storage
        #expect(manager.getProgress(id: "item1") == 0.3)
        #expect(manager.getProgress(id: "item2") == 0.7)
    }

    // MARK: - getProgress Tests

    @Test("getProgress returns 0.0 for non-existent id")
    func testGetProgressNonExistent() throws {
        // Given: Manager with no items
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // When: Getting non-existent progress
        let value = manager.getProgress(id: "non_existent")

        // Then: Should return 0.0
        #expect(value == 0.0)
    }

    @Test("getProgress returns cached value")
    func testGetProgressReturnsCachedValue() async throws {
        // Given: Manager with cached items
        let items = [ProgressItem.mock(id: "item1", value: 0.65)]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to load cache
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Getting progress
        let value = manager.getProgress(id: "item1")

        // Then: Should return cached value
        #expect(value == 0.65)
    }

    @Test("getProgress is synchronous")
    func testGetProgressSynchronous() async throws {
        // Given: Manager with items
        let items = [ProgressItem.mock(id: "sync_test", value: 0.5)]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to load cache
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Calling getProgress (not async)
        let value = manager.getProgress(id: "sync_test")

        // Then: Should return immediately without await
        #expect(value == 0.5)
    }

    // MARK: - getProgressItem Tests

    @Test("getProgressItem returns full ProgressItem")
    func testGetProgressItemReturnsFull() async throws {
        // Given: Manager with item
        let item = ProgressItem.mock(id: "item1", value: 0.75)
        let services = MockProgressServices(items: [item])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to load cache
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Getting progress item
        let result = manager.getProgressItem(id: "item1")

        // Then: Should return full ProgressItem
        #expect(result != nil)
        #expect(result?.id == "item1")
        #expect(result?.value == 0.75)
    }

    @Test("getProgressItem returns nil for non-existent id")
    func testGetProgressItemReturnsNil() throws {
        // Given: Manager with no items
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // When: Getting non-existent item
        let result = manager.getProgressItem(id: "non_existent")

        // Then: Should return nil
        #expect(result == nil)
    }

    // MARK: - getAllProgress Tests

    @Test("getAllProgress returns dictionary of values")
    func testGetAllProgressReturnsDictionary() async throws {
        // Given: Manager with multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7),
            ProgressItem.mock(id: "item3", value: 0.5)
        ]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to load cache
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Getting all progress
        let result = manager.getAllProgress()

        // Then: Should return dictionary with all values
        #expect(result.count == 3)
        #expect(result["item1"] == 0.3)
        #expect(result["item2"] == 0.7)
        #expect(result["item3"] == 0.5)
    }

    @Test("getAllProgress returns empty dictionary when no items")
    func testGetAllProgressReturnsEmpty() throws {
        // Given: Manager with no items
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // When: Getting all progress
        let result = manager.getAllProgress()

        // Then: Should return empty dictionary
        #expect(result.isEmpty)
    }

    // MARK: - getAllProgressItems Tests

    @Test("getAllProgressItems returns all ProgressItem objects")
    func testGetAllProgressItemsReturnsAll() async throws {
        // Given: Manager with multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to load cache
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Getting all progress items
        let result = manager.getAllProgressItems()

        // Then: Should return all ProgressItem objects
        #expect(result.count == 2)
        #expect(result.contains(where: { $0.id == "item1" }))
        #expect(result.contains(where: { $0.id == "item2" }))
    }

    @Test("getAllProgressItems returns empty array when no items")
    func testGetAllProgressItemsReturnsEmpty() throws {
        // Given: Manager with no items
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // When: Getting all progress items
        let result = manager.getAllProgressItems()

        // Then: Should return empty array
        #expect(result.isEmpty)
    }

    // MARK: - getProgressItems filtering Tests

    @Test("getProgressItems filters by metadata field value")
    func testGetProgressItemsFiltersByMetadata() async throws {
        // Given: Manager with items having different metadata
        let items = [
            ProgressItem(
                id: "level1",
                progressKey: "default",
                value: 0.5,
                metadata: ["world": .string("world1"), "type": .string("level")]
            ),
            ProgressItem(
                id: "level2",
                progressKey: "default",
                value: 0.8,
                metadata: ["world": .string("world1"), "type": .string("level")]
            ),
            ProgressItem(
                id: "level3",
                progressKey: "default",
                value: 0.3,
                metadata: ["world": .string("world2"), "type": .string("level")]
            )
        ]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to load cache
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Filtering by world = "world1"
        let result = manager.getProgressItems(forMetadataField: "world", equalTo: .string("world1"))

        // Then: Should return only items from world1
        #expect(result.count == 2)
        #expect(result.contains(where: { $0.id == "level1" }))
        #expect(result.contains(where: { $0.id == "level2" }))
        #expect(!result.contains(where: { $0.id == "level3" }))
    }

    @Test("getProgressItems returns empty array when no matches")
    func testGetProgressItemsReturnsEmptyWhenNoMatches() async throws {
        // Given: Manager with items
        let items = [
            ProgressItem(
                id: "item1",
                progressKey: "default",
                value: 0.5,
                metadata: ["category": .string("A")]
            )
        ]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to load cache
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Filtering by non-existent value
        let result = manager.getProgressItems(forMetadataField: "category", equalTo: .string("B"))

        // Then: Should return empty array
        #expect(result.isEmpty)
    }

    // MARK: - getMaxProgress Tests

    @Test("getMaxProgress returns max value for filtered items")
    func testGetMaxProgressReturnsMax() async throws {
        // Given: Manager with items having different values in same category
        let items = [
            ProgressItem(
                id: "level1",
                progressKey: "default",
                value: 0.5,
                metadata: ["world": .string("world1")]
            ),
            ProgressItem(
                id: "level2",
                progressKey: "default",
                value: 0.9,
                metadata: ["world": .string("world1")]
            ),
            ProgressItem(
                id: "level3",
                progressKey: "default",
                value: 0.3,
                metadata: ["world": .string("world1")]
            ),
            ProgressItem(
                id: "level4",
                progressKey: "default",
                value: 1.0,
                metadata: ["world": .string("world2")]
            )
        ]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to load cache
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Getting max progress for world1
        let result = manager.getMaxProgress(forMetadataField: "world", equalTo: .string("world1"))

        // Then: Should return max value from world1 (0.9)
        #expect(result == 0.9)
    }

    @Test("getMaxProgress returns 0.0 when no items match")
    func testGetMaxProgressReturnsZeroWhenNoMatches() async throws {
        // Given: Manager with items
        let items = [
            ProgressItem(
                id: "item1",
                progressKey: "default",
                value: 0.5,
                metadata: ["category": .string("A")]
            )
        ]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // Give async init time to load cache
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Getting max for non-existent category
        let result = manager.getMaxProgress(forMetadataField: "category", equalTo: .string("B"))

        // Then: Should return 0.0
        #expect(result == 0.0)
    }

    @Test("getMaxProgress returns 0.0 when manager has no items")
    func testGetMaxProgressReturnsZeroWhenEmpty() throws {
        // Given: Manager with no items
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // When: Getting max progress
        let result = manager.getMaxProgress(forMetadataField: "any", equalTo: .string("value"))

        // Then: Should return 0.0
        #expect(result == 0.0)
    }

    // MARK: - Login Tests

    @Test("logIn performs bulk load")
    func testLoginBulkLoad() async throws {
        // Given: Remote has items, local is empty
        let remoteItems = [
            ProgressItem.mock(id: "remote1", value: 0.4),
            ProgressItem.mock(id: "remote2", value: 0.8)
        ]
        let services = MockProgressServices(items: [])
        let remote = services.remote as! MockRemoteProgressService

        // Add items to remote
        for item in remoteItems {
            try await remote.addProgress(userId: "user123", progressKey: "default", item: item)
        }

        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // When: Logging in
        try await manager.logIn(userId: "user123")

        // Give bulk load time to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should load all items into cache
        #expect(manager.getProgress(id: "remote1") == 0.4)
        #expect(manager.getProgress(id: "remote2") == 0.8)
    }

    @Test("logIn starts remote listener")
    func testLoginStartsRemoteListener() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"), logger: logger)

        // When: Logging in
        try await manager.logIn(userId: "user123")

        // Give listener time to start
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should log listener start event
        #expect(logger.trackedEvents.contains("ProgressMan_RemoteListener_Start"))
    }

    // MARK: - Logout Tests

    @Test("logOut clears cache")
    func testLogoutClearsCache() async throws {
        // Given: Manager with items and logged in
        let items = [ProgressItem.mock(id: "item1", value: 0.5)]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Logging out
        await manager.logOut()

        // Then: Cache should be cleared
        #expect(manager.getProgress(id: "item1") == 0.0)
    }

    // MARK: - addProgress Tests

    @Test("addProgress requires login")
    func testUpdateProgressRequiresLogin() async throws {
        // Given: Manager not logged in
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // When/Then: Updating should throw
        await #expect(throws: ProgressError.self) {
            try await manager.addProgress(id: "item1", value: 0.5)
        }
    }

    @Test("addProgress validates value range")
    func testUpdateProgressValidatesRange() async throws {
        // Given: Logged in manager
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When/Then: Negative value should throw
        await #expect(throws: ProgressError.self) {
            try await manager.addProgress(id: "item1", value: -0.1)
        }

        // When/Then: Value > 1.0 should throw
        await #expect(throws: ProgressError.self) {
            try await manager.addProgress(id: "item1", value: 1.1)
        }
    }

    @Test("addProgress accepts valid range")
    func testUpdateProgressValidRange() async throws {
        // Given: Logged in manager
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Updating with 0.0
        try await manager.addProgress(id: "item1", value: 0.0)

        // Then: Should succeed
        #expect(manager.getProgress(id: "item1") == 0.0)

        // When: Updating with 1.0
        try await manager.addProgress(id: "item2", value: 1.0)

        // Then: Should succeed
        #expect(manager.getProgress(id: "item2") == 1.0)
    }

    @Test("addProgress updates cache optimistically")
    func testUpdateProgressOptimistic() async throws {
        // Given: Logged in manager
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Updating progress
        let updateTask = Task {
            try await manager.addProgress(id: "item1", value: 0.75)
        }

        // Then: Cache should be updated immediately (before remote completes)
        // Note: This test relies on optimistic update behavior
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(manager.getProgress(id: "item1") == 0.75)

        try await updateTask.value
    }

    @Test("addProgress saves to local storage")
    func testUpdateProgressSavesLocal() async throws {
        // Given: Logged in manager
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Updating progress
        try await manager.addProgress(id: "item1", value: 0.55)

        // Then: Should save to local storage
        let local = services.local
        let savedItem = local.getProgressItem(progressKey: "default", id: "item1")
        #expect(savedItem?.value == 0.55)
    }

    @Test("addProgress saves to remote")
    func testUpdateProgressSavesRemote() async throws {
        // Given: Logged in manager
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Updating progress
        try await manager.addProgress(id: "item1", value: 0.45)

        // Then: Should save to remote
        let remote = services.remote
        let remoteItems = try await remote.getAllProgressItems(userId: "user123", progressKey: "default")
        #expect(remoteItems.contains(where: { $0.id == "item1" && $0.value == 0.45 }))
    }

    @Test("addProgress preserves dateCreated for existing items")
    func testUpdateProgressPreservesDateCreated() async throws {
        // Given: Manager with existing item
        let originalDate = Date(timeIntervalSince1970: 1609459200)
        let existingItem = ProgressItem(id: "item1", progressKey: "default", value: 0.3, dateCreated: originalDate, dateModified: originalDate)
        let services = MockProgressServices(items: [existingItem])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Updating the item
        try await manager.addProgress(id: "item1", value: 0.7)

        // Then: Should preserve original dateCreated
        let local = services.local
        let updatedItem = local.getProgressItem(progressKey: "default", id: "item1")
        #expect(updatedItem?.dateCreated == originalDate)
    }

    @Test("addProgress updates dateModified")
    func testUpdateProgressUpdatesDateModified() async throws {
        // Given: Manager with existing item
        let oldDate = Date(timeIntervalSince1970: 1609459200)
        let existingItem = ProgressItem(id: "item1", progressKey: "default", value: 0.3, dateCreated: oldDate, dateModified: oldDate)
        let services = MockProgressServices(items: [existingItem])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Updating the item
        let before = Date()
        try await manager.addProgress(id: "item1", value: 0.7)
        let after = Date()

        // Then: Should update dateModified to current time
        let local = services.local
        let updatedItem = local.getProgressItem(progressKey: "default", id: "item1")
        #expect(updatedItem?.dateModified ?? Date.distantPast >= before)
        #expect(updatedItem?.dateModified ?? Date.distantFuture <= after)
    }

    @Test("addProgress logs events")
    func testUpdateProgressLogsEvents() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"), logger: logger)
        try await manager.logIn(userId: "user123")

        // When: Updating progress
        try await manager.addProgress(id: "item1", value: 0.6)

        // Then: Should log start and success events
        #expect(logger.trackedEvents.contains("ProgressMan_AddProgress_Start"))
        #expect(logger.trackedEvents.contains("ProgressMan_AddProgress_Success"))
    }

    @Test("addProgress merges metadata with existing metadata")
    func testAddProgressMergesMetadata() async throws {
        // Given: Manager with item that has metadata
        let existingItem = ProgressItem(
            id: "item1",
            progressKey: "default",
            value: 0.5,
            dateCreated: Date(),
            dateModified: Date(),
            metadata: ["key1": .string("value1"), "key2": .int(42)]
        )
        let services = MockProgressServices(items: [existingItem])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // Give async init time to load
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Updating with new metadata
        try await manager.addProgress(
            id: "item1",
            value: 0.7,
            metadata: ["key2": .int(99), "key3": .string("new")]
        )

        // Then: Should merge metadata (new values overwrite old ones)
        let updated = manager.getProgressItem(id: "item1")
        #expect(updated?.metadata["key1"] == .string("value1")) // Preserved
        #expect(updated?.metadata["key2"] == .int(99)) // Overwritten
        #expect(updated?.metadata["key3"] == .string("new")) // Added
    }

    @Test("addProgress with nil metadata preserves existing metadata")
    func testAddProgressNilMetadataPreservesExisting() async throws {
        // Given: Manager with item that has metadata
        let existingItem = ProgressItem(
            id: "item1",
            progressKey: "default",
            value: 0.5,
            dateCreated: Date(),
            dateModified: Date(),
            metadata: ["key1": .string("value1")]
        )
        let services = MockProgressServices(items: [existingItem])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // Give async init time to load
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Updating without providing metadata
        try await manager.addProgress(id: "item1", value: 0.7, metadata: nil)

        // Then: Should preserve existing metadata
        let updated = manager.getProgressItem(id: "item1")
        #expect(updated?.metadata["key1"] == .string("value1"))
    }

    @Test("addProgress with empty metadata preserves existing metadata")
    func testAddProgressEmptyMetadataPreservesExisting() async throws {
        // Given: Manager with item that has metadata
        let existingItem = ProgressItem(
            id: "item1",
            progressKey: "default",
            value: 0.5,
            dateCreated: Date(),
            dateModified: Date(),
            metadata: ["key1": .string("value1")]
        )
        let services = MockProgressServices(items: [existingItem])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // Give async init time to load
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Updating with empty metadata dictionary
        try await manager.addProgress(id: "item1", value: 0.7, metadata: [:])

        // Then: Should preserve existing metadata
        let updated = manager.getProgressItem(id: "item1")
        #expect(updated?.metadata["key1"] == .string("value1"))
    }

    // MARK: - deleteProgress Tests

    @Test("deleteProgress requires login")
    func testDeleteProgressRequiresLogin() async throws {
        // Given: Manager not logged in
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // When/Then: Deleting should throw
        await #expect(throws: ProgressError.self) {
            try await manager.deleteProgress(id: "item1")
        }
    }

    @Test("deleteProgress removes from cache")
    func testDeleteProgressRemovesFromCache() async throws {
        // Given: Manager with item
        let items = [ProgressItem.mock(id: "item1", value: 0.5)]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Deleting progress
        try await manager.deleteProgress(id: "item1")

        // Then: Should remove from cache
        #expect(manager.getProgress(id: "item1") == 0.0)
    }

    @Test("deleteProgress removes from local storage")
    func testDeleteProgressRemovesLocal() async throws {
        // Given: Manager with item
        let items = [ProgressItem.mock(id: "item1", value: 0.5)]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Deleting progress
        try await manager.deleteProgress(id: "item1")

        // Then: Should remove from local storage
        let local = services.local
        #expect(local.getProgressItem(progressKey: "default", id: "item1") == nil)
    }

    @Test("deleteProgress removes from remote")
    func testDeleteProgressRemovesRemote() async throws {
        // Given: Manager with item
        let items = [ProgressItem.mock(id: "item1", value: 0.5)]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Deleting progress
        try await manager.deleteProgress(id: "item1")

        // Then: Should remove from remote
        let remote = services.remote
        let remoteItems = try await remote.getAllProgressItems(userId: "user123", progressKey: "default")
        #expect(!remoteItems.contains(where: { $0.id == "item1" }))
    }

    // MARK: - deleteAllProgress Tests

    @Test("deleteAllProgress requires login")
    func testDeleteAllProgressRequiresLogin() async throws {
        // Given: Manager not logged in
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))

        // When/Then: Deleting all should throw
        await #expect(throws: ProgressError.self) {
            try await manager.deleteAllProgress()
        }
    }

    @Test("deleteAllProgress clears cache")
    func testDeleteAllProgressClearsCache() async throws {
        // Given: Manager with multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Deleting all progress
        try await manager.deleteAllProgress()

        // Then: Cache should be empty
        #expect(manager.getProgress(id: "item1") == 0.0)
        #expect(manager.getProgress(id: "item2") == 0.0)
    }

    @Test("deleteAllProgress clears local storage")
    func testDeleteAllProgressClearsLocal() async throws {
        // Given: Manager with multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Deleting all progress
        try await manager.deleteAllProgress()

        // Then: Local storage should be empty
        let local = services.local
        #expect(local.getAllProgressItems(progressKey: "default").isEmpty)
    }

    @Test("deleteAllProgress clears remote")
    func testDeleteAllProgressClearsRemote() async throws {
        // Given: Manager with multiple items
        let items = [
            ProgressItem.mock(id: "item1", value: 0.3),
            ProgressItem.mock(id: "item2", value: 0.7)
        ]
        let services = MockProgressServices(items: items)
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // When: Deleting all progress
        try await manager.deleteAllProgress()

        // Then: Remote should be empty
        let remote = services.remote
        let remoteItems = try await remote.getAllProgressItems(userId: "user123", progressKey: "default")
        #expect(remoteItems.isEmpty)
    }

    // MARK: - Analytics Tests

    @Test("Manager logs bulk load events")
    func testBulkLoadLogsEvents() async throws {
        // Given: Manager with logger and remote items
        let logger = MockGamificationLogger()
        let services = MockProgressServices(items: [])
        let remote = services.remote as! MockRemoteProgressService
        try await remote.addProgress(userId: "user123", progressKey: "default", item: ProgressItem.mock(id: "item1", value: 0.5))

        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"), logger: logger)

        // When: Logging in (triggers bulk load)
        try await manager.logIn(userId: "user123")

        // Give bulk load time to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should log bulk load events
        #expect(logger.trackedEvents.contains("ProgressMan_BulkLoad_Start"))
        #expect(logger.trackedEvents.contains("ProgressMan_BulkLoad_Success"))
    }

    @Test("Manager logs delete events")
    func testDeleteLogsEvents() async throws {
        // Given: Manager with logger and item
        let logger = MockGamificationLogger()
        let services = MockProgressServices(items: [ProgressItem.mock(id: "item1", value: 0.5)])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"), logger: logger)
        try await manager.logIn(userId: "user123")

        // Clear previous events
        logger.trackedEvents.removeAll()

        // When: Deleting progress
        try await manager.deleteProgress(id: "item1")

        // Then: Should log delete events
        #expect(logger.trackedEvents.contains("ProgressMan_DeleteProgress_Start"))
        #expect(logger.trackedEvents.contains("ProgressMan_DeleteProgress_Success"))
    }

    @Test("Manager logs delete all events")
    func testDeleteAllLogsEvents() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"), logger: logger)
        try await manager.logIn(userId: "user123")

        // Clear previous events
        logger.trackedEvents.removeAll()

        // When: Deleting all progress
        try await manager.deleteAllProgress()

        // Then: Should log delete all events
        #expect(logger.trackedEvents.contains("ProgressMan_DeleteAllProgress_Start"))
        #expect(logger.trackedEvents.contains("ProgressMan_DeleteAllProgress_Success"))
    }

    // MARK: - Progress Decrease Prevention Tests

    @Test("addProgress does not decrease existing progress value")
    func testAddProgressDoesNotDecrease() async throws {
        // Given: Manager with existing progress
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // Add initial progress
        try await manager.addProgress(id: "item1", value: 0.8)

        // Wait for cache to load
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Adding lower value
        try await manager.addProgress(id: "item1", value: 0.5)

        // Wait for update
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should keep higher value
        let item = manager.getProgressItem(id: "item1")
        #expect(item?.value == 0.8)
    }

    @Test("addProgress updates when new value is higher")
    func testAddProgressUpdatesWhenHigher() async throws {
        // Given: Manager with existing progress
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // Add initial progress
        try await manager.addProgress(id: "item1", value: 0.5)

        // Wait for cache to load
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Adding higher value
        try await manager.addProgress(id: "item1", value: 0.9)

        // Wait for update
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should update to higher value
        let item = manager.getProgressItem(id: "item1")
        #expect(item?.value == 0.9)
    }

    @Test("Remote listener respects local higher value")
    func testRemoteListenerRespectsLocalValue() async throws {
        // Given: Manager with local progress
        let services = MockProgressServices(items: [])
        let manager = ProgressManager(services: services, configuration: ProgressConfiguration(progressKey: "default"))
        try await manager.logIn(userId: "user123")

        // Add high value locally
        try await manager.addProgress(id: "item1", value: 0.9)

        // Wait for cache to load
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Remote sends lower value
        let remote = services.remote as! MockRemoteProgressService
        let lowerItem = ProgressItem(id: "item1", progressKey: "default", value: 0.6)
        try await remote.addProgress(userId: "user123", progressKey: "default", item: lowerItem)

        // Wait for listener update
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should keep local higher value
        let item = manager.getProgressItem(id: "item1")
        #expect(item?.value == 0.9)
    }
}
