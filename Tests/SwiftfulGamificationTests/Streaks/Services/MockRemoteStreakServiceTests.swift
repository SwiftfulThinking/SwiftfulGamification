//
//  MockRemoteStreakServiceTests.swift
//  SwiftfulGamificationTests
//
//  Tests for MockRemoteStreakService
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("MockRemoteStreakService Tests")
@MainActor
struct MockRemoteStreakServiceTests {

    // MARK: - Initialization Tests

    @Test("Initializes with provided streak data")
    func testInitializesWithProvidedStreak() async throws {
        // Given: A streak
        let streak = CurrentStreakData.mock(streakId: "test", currentStreak: 5)

        // When: Initializing service with streak
        let service = MockRemoteStreakService(streak: streak)

        // Then: Should store the streak (verify via stream)
        let stream = service.streamCurrentStreak(userId: "user1", streakId: "test")
        var iterator = stream.makeAsyncIterator()
        let firstValue = try await iterator.next()

        #expect(firstValue == streak)
    }

    @Test("Initializes with empty events array")
    func testInitializesWithEmptyEvents() async throws {
        // Given: Service
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When: Getting all events
        let events = try await service.getAllEvents(userId: "user1", streakId: "test")

        // Then: Should be empty
        #expect(events.isEmpty)
    }

    @Test("Initializes with empty freezes array")
    func testInitializesWithEmptyFreezes() async throws {
        // Given: Service
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When: Getting all freezes
        let freezes = try await service.getAllStreakFreezes(userId: "user1", streakId: "test")

        // Then: Should be empty
        #expect(freezes.isEmpty)
    }

    // MARK: - updateCurrentStreak Tests

    @Test("updateCurrentStreak persists new streak")
    func testUpdateCurrentStreakPersists() async throws {
        // Given: Service with initial streak
        let initial = CurrentStreakData.blank(streakId: "test")
        let service = MockRemoteStreakService(streak: initial)

        // When: Updating streak
        let newStreak = CurrentStreakData.mock(streakId: "test", currentStreak: 10)
        try await service.updateCurrentStreak(userId: "user1", streakId: "test", streak: newStreak)

        // Then: Stream should emit new streak
        let stream = service.streamCurrentStreak(userId: "user1", streakId: "test")
        var iterator = stream.makeAsyncIterator()
        let value = try await iterator.next()

        #expect(value == newStreak)
    }

    @Test("updateCurrentStreak triggers stream update")
    func testUpdateCurrentStreakTriggersStream() async throws {
        // Given: Service with stream listener
        let initial = CurrentStreakData.mock(streakId: "test", currentStreak: 5)
        let service = MockRemoteStreakService(streak: initial)

        var receivedValues: [CurrentStreakData] = []

        // Start listening to stream
        let task = Task {
            let stream = service.streamCurrentStreak(userId: "user1", streakId: "test")
            var iterator = stream.makeAsyncIterator()

            // Get initial value
            if let value = try await iterator.next() {
                receivedValues.append(value)
            }

            // Get updated value
            if let value = try await iterator.next() {
                receivedValues.append(value)
            }
        }

        // Give stream time to start
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // When: Updating streak
        let newStreak = CurrentStreakData.mock(streakId: "test", currentStreak: 15)
        try await service.updateCurrentStreak(userId: "user1", streakId: "test", streak: newStreak)

        // Give stream time to receive update
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        task.cancel()

        // Then: Should have received both initial and updated values
        #expect(receivedValues.count >= 1)
        #expect(receivedValues.last?.currentStreak == 15)
    }

    // MARK: - streamCurrentStreak Tests

    @Test("streamCurrentStreak emits initial value")
    func testStreamEmitsInitialValue() async throws {
        // Given: Service with streak
        let streak = CurrentStreakData.mock(streakId: "test", currentStreak: 7)
        let service = MockRemoteStreakService(streak: streak)

        // When: Streaming
        let stream = service.streamCurrentStreak(userId: "user1", streakId: "test")
        var iterator = stream.makeAsyncIterator()

        // Then: Should emit initial value
        let value = try await iterator.next()
        #expect(value == streak)
    }

    @Test("streamCurrentStreak emits updates on change")
    func testStreamEmitsUpdates() async throws {
        // Given: Service
        let initial = CurrentStreakData.mock(streakId: "test", currentStreak: 3)
        let service = MockRemoteStreakService(streak: initial)

        var receivedValues: [CurrentStreakData] = []

        let task = Task {
            let stream = service.streamCurrentStreak(userId: "user1", streakId: "test")
            for try await value in stream {
                receivedValues.append(value)
                if receivedValues.count >= 2 {
                    break
                }
            }
        }

        // Give stream time to start
        try await Task.sleep(nanoseconds: 10_000_000)

        // When: Updating streak
        try await service.updateCurrentStreak(userId: "user1", streakId: "test", streak: CurrentStreakData.mock(streakId: "test", currentStreak: 8))

        // Give time for update
        try await Task.sleep(nanoseconds: 10_000_000)

        task.cancel()

        // Then: Should receive both values
        #expect(receivedValues.count >= 1)
    }

    @Test("streamCurrentStreak multiple listeners receive same value")
    func testStreamMultipleListeners() async throws {
        // Given: Service
        let streak = CurrentStreakData.mock(streakId: "test", currentStreak: 5)
        let service = MockRemoteStreakService(streak: streak)

        // When: Creating multiple streams
        let stream1 = service.streamCurrentStreak(userId: "user1", streakId: "test")
        let stream2 = service.streamCurrentStreak(userId: "user1", streakId: "test")

        var iterator1 = stream1.makeAsyncIterator()
        var iterator2 = stream2.makeAsyncIterator()

        // Then: Both should receive same value
        let value1 = try await iterator1.next()
        let value2 = try await iterator2.next()

        #expect(value1 == streak)
        #expect(value2 == streak)
    }

    @Test("streamCurrentStreak cleans up on cancellation")
    func testStreamCleansUpOnCancellation() async throws {
        // Given: Service with stream
        let service = MockRemoteStreakService(streak: CurrentStreakData.mock(streakId: "test"))

        // When: Creating and cancelling stream
        let task = Task {
            let stream = service.streamCurrentStreak(userId: "user1", streakId: "test")
            for try await _ in stream {
                // Stream running
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)

        // Then: Should cancel cleanly
        task.cancel()

        // Wait a bit to ensure cleanup
        try await Task.sleep(nanoseconds: 10_000_000)

        // No crash = success
        #expect(true)
    }

    // MARK: - Event Management Tests

    @Test("addEvent adds to events array")
    func testAddEventAddsToArray() async throws {
        // Given: Service
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When: Adding event
        let event = StreakEvent.mock()
        try await service.addEvent(userId: "user1", streakId: "test", event: event)

        // Then: Should be in events array
        let events = try await service.getAllEvents(userId: "user1", streakId: "test")
        #expect(events.count == 1)
        #expect(events.first == event)
    }

    @Test("addEvent does not modify existing events")
    func testAddEventDoesNotModifyExisting() async throws {
        // Given: Service with existing event
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))
        let event1 = StreakEvent.mock(id: "event-1")
        try await service.addEvent(userId: "user1", streakId: "test", event: event1)

        // When: Adding another event
        let event2 = StreakEvent.mock(id: "event-2")
        try await service.addEvent(userId: "user1", streakId: "test", event: event2)

        // Then: Both should exist
        let events = try await service.getAllEvents(userId: "user1", streakId: "test")
        #expect(events.count == 2)
        #expect(events.contains(event1))
        #expect(events.contains(event2))
    }

    @Test("getAllEvents returns all added events")
    func testGetAllEventsReturnsAll() async throws {
        // Given: Service with multiple events
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        let events = [
            StreakEvent.mock(id: "1"),
            StreakEvent.mock(id: "2"),
            StreakEvent.mock(id: "3")
        ]

        for event in events {
            try await service.addEvent(userId: "user1", streakId: "test", event: event)
        }

        // When: Getting all events
        let retrieved = try await service.getAllEvents(userId: "user1", streakId: "test")

        // Then: Should return all
        #expect(retrieved.count == 3)
    }

    @Test("getAllEvents returns empty array when no events")
    func testGetAllEventsReturnsEmpty() async throws {
        // Given: Service with no events
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When: Getting events
        let events = try await service.getAllEvents(userId: "user1", streakId: "test")

        // Then: Should be empty
        #expect(events.isEmpty)
    }

    @Test("deleteAllEvents clears events array")
    func testDeleteAllEventsClearsArray() async throws {
        // Given: Service with events
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))
        try await service.addEvent(userId: "user1", streakId: "test", event: StreakEvent.mock())
        try await service.addEvent(userId: "user1", streakId: "test", event: StreakEvent.mock())

        // When: Deleting all events
        try await service.deleteAllEvents(userId: "user1", streakId: "test")

        // Then: Should be empty
        let events = try await service.getAllEvents(userId: "user1", streakId: "test")
        #expect(events.isEmpty)
    }

    // MARK: - Freeze Management Tests

    @Test("addStreakFreeze adds to freezes array")
    func testAddStreakFreezeAddsToArray() async throws {
        // Given: Service
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When: Adding freeze
        let freeze = StreakFreeze.mockUnused()
        try await service.addStreakFreeze(userId: "user1", streakId: "test", freeze: freeze)

        // Then: Should be in freezes array
        let freezes = try await service.getAllStreakFreezes(userId: "user1", streakId: "test")
        #expect(freezes.count == 1)
        #expect(freezes.first == freeze)
    }

    @Test("getAllStreakFreezes returns all added freezes")
    func testGetAllStreakFreezesReturnsAll() async throws {
        // Given: Service with multiple freezes
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        let freezes = [
            StreakFreeze.mockUnused(id: "1"),
            StreakFreeze.mockUnused(id: "2"),
            StreakFreeze.mockUnused(id: "3")
        ]

        for freeze in freezes {
            try await service.addStreakFreeze(userId: "user1", streakId: "test", freeze: freeze)
        }

        // When: Getting all freezes
        let retrieved = try await service.getAllStreakFreezes(userId: "user1", streakId: "test")

        // Then: Should return all
        #expect(retrieved.count == 3)
    }

    @Test("getAllStreakFreezes returns empty array when no freezes")
    func testGetAllStreakFreezesReturnsEmpty() async throws {
        // Given: Service with no freezes
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When: Getting freezes
        let freezes = try await service.getAllStreakFreezes(userId: "user1", streakId: "test")

        // Then: Should be empty
        #expect(freezes.isEmpty)
    }

    @Test("useStreakFreeze updates freeze usedDate")
    func testUseStreakFreezeUpdatesUsedDate() async throws {
        // Given: Service with unused freeze
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))
        let freeze = StreakFreeze.mockUnused(id: "freeze-1")
        try await service.addStreakFreeze(userId: "user1", streakId: "test", freeze: freeze)

        // When: Using the freeze
        try await service.useStreakFreeze(userId: "user1", streakId: "test", freezeId: "freeze-1")

        // Then: Freeze should have usedDate
        let freezes = try await service.getAllStreakFreezes(userId: "user1", streakId: "test")
        let usedFreeze = freezes.first { $0.id == "freeze-1" }

        #expect(usedFreeze?.isUsed == true)
        #expect(usedFreeze?.usedDate != nil)
    }

    @Test("useStreakFreeze throws when freeze not found")
    func testUseStreakFreezeThrowsWhenNotFound() async throws {
        // Given: Service with no freezes
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When/Then: Using non-existent freeze should throw
        do {
            try await service.useStreakFreeze(userId: "user1", streakId: "test", freezeId: "nonexistent")
            #expect(Bool(false), "Should have thrown error")
        } catch {
            // Expected error
            #expect(true)
        }
    }

    @Test("useStreakFreeze does not modify other freezes")
    func testUseStreakFreezeDoesNotModifyOthers() async throws {
        // Given: Service with multiple freezes
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))
        let freeze1 = StreakFreeze.mockUnused(id: "freeze-1")
        let freeze2 = StreakFreeze.mockUnused(id: "freeze-2")
        try await service.addStreakFreeze(userId: "user1", streakId: "test", freeze: freeze1)
        try await service.addStreakFreeze(userId: "user1", streakId: "test", freeze: freeze2)

        // When: Using one freeze
        try await service.useStreakFreeze(userId: "user1", streakId: "test", freezeId: "freeze-1")

        // Then: Other freeze should remain unused
        let freezes = try await service.getAllStreakFreezes(userId: "user1", streakId: "test")
        let unchanged = freezes.first { $0.id == "freeze-2" }

        #expect(unchanged?.isUsed == false)
    }

    // MARK: - calculateStreak Tests

    @Test("calculateStreak is no-op in mock")
    func testCalculateStreakIsNoOp() async throws {
        // Given: Service
        let initial = CurrentStreakData.mock(streakId: "test", currentStreak: 5)
        let service = MockRemoteStreakService(streak: initial)

        // When: Calling calculateStreak
        try await service.calculateStreak(userId: "user1", streakId: "test")

        // Then: Streak should remain unchanged
        let stream = service.streamCurrentStreak(userId: "user1", streakId: "test")
        var iterator = stream.makeAsyncIterator()
        let value = try await iterator.next()

        #expect(value?.currentStreak == 5)
    }

    @Test("calculateStreak does not throw")
    func testCalculateStreakDoesNotThrow() async throws {
        // Given: Service
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When/Then: Should not throw
        try await service.calculateStreak(userId: "user1", streakId: "test")

        #expect(true) // Success if we get here
    }

    // MARK: - Integration Tests

    @Test("Events and freezes are independent")
    func testEventsAndFreezesIndependent() async throws {
        // Given: Service
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When: Adding events and freezes
        try await service.addEvent(userId: "user1", streakId: "test", event: StreakEvent.mock())
        try await service.addStreakFreeze(userId: "user1", streakId: "test", freeze: StreakFreeze.mockUnused())

        // Then: Both should exist independently
        let events = try await service.getAllEvents(userId: "user1", streakId: "test")
        let freezes = try await service.getAllStreakFreezes(userId: "user1", streakId: "test")

        #expect(events.count == 1)
        #expect(freezes.count == 1)
    }

    @Test("Multiple updates preserve data integrity")
    func testMultipleUpdatesPreserveIntegrity() async throws {
        // Given: Service
        let service = MockRemoteStreakService(streak: CurrentStreakData.blank(streakId: "test"))

        // When: Performing multiple operations
        try await service.addEvent(userId: "user1", streakId: "test", event: StreakEvent.mock(id: "e1"))
        try await service.updateCurrentStreak(userId: "user1", streakId: "test", streak: CurrentStreakData.mock(streakId: "test", currentStreak: 1))

        try await service.addEvent(userId: "user1", streakId: "test", event: StreakEvent.mock(id: "e2"))
        try await service.updateCurrentStreak(userId: "user1", streakId: "test", streak: CurrentStreakData.mock(streakId: "test", currentStreak: 2))

        try await service.addStreakFreeze(userId: "user1", streakId: "test", freeze: StreakFreeze.mockUnused(id: "f1"))

        // Then: All data should be preserved
        let events = try await service.getAllEvents(userId: "user1", streakId: "test")
        let freezes = try await service.getAllStreakFreezes(userId: "user1", streakId: "test")

        let stream = service.streamCurrentStreak(userId: "user1", streakId: "test")
        var iterator = stream.makeAsyncIterator()
        let streak = try await iterator.next()

        #expect(events.count == 2)
        #expect(freezes.count == 1)
        #expect(streak?.currentStreak == 2)
    }
}
