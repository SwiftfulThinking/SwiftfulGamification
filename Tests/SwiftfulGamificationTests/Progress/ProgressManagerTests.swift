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
        manager.logOut()

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
}
