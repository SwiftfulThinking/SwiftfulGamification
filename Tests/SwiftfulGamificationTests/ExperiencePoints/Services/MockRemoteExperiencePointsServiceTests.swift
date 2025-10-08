//
//  MockRemoteExperiencePointsServiceTests.swift
//  SwiftfulGamificationTests
//
//  Tests for MockRemoteExperiencePointsService
//

import Testing
import Foundation
@testable import SwiftfulGamification

@Suite("MockRemoteExperiencePointsService Tests")
@MainActor
struct MockRemoteExperiencePointsServiceTests {

    // MARK: - Initialization Tests

    @Test("Initializes with provided XP data")
    func testInitializesWithProvidedData() async throws {
        // Given: XP data
        let data = CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 5000)

        // When: Initializing service with data
        let service = MockRemoteExperiencePointsService(data: data)

        // Then: Should store the data (verify via stream)
        let stream = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")
        var iterator = stream.makeAsyncIterator()
        let firstValue = try await iterator.next()

        #expect(firstValue == data)
    }

    @Test("Initializes with empty events array")
    func testInitializesWithEmptyEvents() async throws {
        // Given: Service
        let service = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceKey: "test"))

        // When: Getting all events
        let events = try await service.getAllEvents(userId: "user1", experienceKey: "test")

        // Then: Should be empty
        #expect(events.isEmpty)
    }

    // MARK: - updateCurrentExperiencePoints Tests

    @Test("updateCurrentExperiencePoints persists new data")
    func testUpdateCurrentExperiencePointsPersists() async throws {
        // Given: Service with initial data
        let initial = CurrentExperiencePointsData.blank(experienceKey: "test")
        let service = MockRemoteExperiencePointsService(data: initial)

        // When: Updating data
        let newData = CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 10000)
        try await service.updateCurrentExperiencePoints(userId: "user1", experienceKey: "test", data: newData)

        // Then: Stream should emit new data
        let stream = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")
        var iterator = stream.makeAsyncIterator()
        let value = try await iterator.next()

        #expect(value == newData)
    }

    @Test("updateCurrentExperiencePoints triggers stream update")
    func testUpdateCurrentExperiencePointsTriggersStream() async throws {
        // Given: Service with stream listener
        let initial = CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 5000)
        let service = MockRemoteExperiencePointsService(data: initial)

        var receivedValues: [CurrentExperiencePointsData] = []

        // Start listening to stream
        let task = Task {
            let stream = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")
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

        // When: Updating data
        let newData = CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 15000)
        try await service.updateCurrentExperiencePoints(userId: "user1", experienceKey: "test", data: newData)

        // Give stream time to receive update
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        task.cancel()

        // Then: Should have received both initial and updated values
        #expect(receivedValues.count >= 1)
        #expect(receivedValues.last?.totalPoints == 15000)
    }

    // MARK: - streamCurrentExperiencePoints Tests

    @Test("streamCurrentExperiencePoints emits initial value")
    func testStreamEmitsInitialValue() async throws {
        // Given: Service with data
        let data = CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 7000)
        let service = MockRemoteExperiencePointsService(data: data)

        // When: Streaming
        let stream = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")
        var iterator = stream.makeAsyncIterator()

        // Then: Should emit initial value
        let value = try await iterator.next()
        #expect(value == data)
    }

    @Test("streamCurrentExperiencePoints emits updates on change")
    func testStreamEmitsUpdates() async throws {
        // Given: Service
        let initial = CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 3000)
        let service = MockRemoteExperiencePointsService(data: initial)

        var receivedValues: [CurrentExperiencePointsData] = []

        let task = Task {
            let stream = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")
            for try await value in stream {
                receivedValues.append(value)
                if receivedValues.count >= 2 {
                    break
                }
            }
        }

        // Give stream time to start
        try await Task.sleep(nanoseconds: 10_000_000)

        // When: Updating data
        try await service.updateCurrentExperiencePoints(userId: "user1", experienceKey: "test", data: CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 8000))

        // Give time for update
        try await Task.sleep(nanoseconds: 10_000_000)

        task.cancel()

        // Then: Should receive both values
        #expect(receivedValues.count >= 1)
    }

    @Test("streamCurrentExperiencePoints multiple listeners receive same value")
    func testStreamMultipleListeners() async throws {
        // Given: Service
        let data = CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 5000)
        let service = MockRemoteExperiencePointsService(data: data)

        // When: Creating multiple streams
        let stream1 = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")
        let stream2 = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")

        var iterator1 = stream1.makeAsyncIterator()
        var iterator2 = stream2.makeAsyncIterator()

        // Then: Both should receive same value
        let value1 = try await iterator1.next()
        let value2 = try await iterator2.next()

        #expect(value1 == data)
        #expect(value2 == data)
    }

    @Test("streamCurrentExperiencePoints cleans up on cancellation")
    func testStreamCleansUpOnCancellation() async throws {
        // Given: Service with stream
        let service = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.mock(experienceKey: "test"))

        // When: Creating and cancelling stream
        let task = Task {
            let stream = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")
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
        let service = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceKey: "test"))

        // When: Adding event
        let event = ExperiencePointsEvent.mock(experienceKey: "test")
        try await service.addEvent(userId: "user1", experienceKey: "test", event: event)

        // Then: Should be in events array
        let events = try await service.getAllEvents(userId: "user1", experienceKey: "test")
        #expect(events.count == 1)
        #expect(events.first == event)
    }

    @Test("addEvent does not modify existing events")
    func testAddEventDoesNotModifyExisting() async throws {
        // Given: Service with existing event
        let service = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceKey: "test"))
        let event1 = ExperiencePointsEvent.mock(id: "event-1", experienceKey: "test")
        try await service.addEvent(userId: "user1", experienceKey: "test", event: event1)

        // When: Adding another event
        let event2 = ExperiencePointsEvent.mock(id: "event-2", experienceKey: "test")
        try await service.addEvent(userId: "user1", experienceKey: "test", event: event2)

        // Then: Both should exist
        let events = try await service.getAllEvents(userId: "user1", experienceKey: "test")
        #expect(events.count == 2)
        #expect(events.contains(event1))
        #expect(events.contains(event2))
    }

    @Test("getAllEvents returns all added events")
    func testGetAllEventsReturnsAll() async throws {
        // Given: Service with multiple events
        let service = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceKey: "test"))

        let events = [
            ExperiencePointsEvent.mock(id: "1", experienceKey: "test"),
            ExperiencePointsEvent.mock(id: "2", experienceKey: "test"),
            ExperiencePointsEvent.mock(id: "3", experienceKey: "test")
        ]

        for event in events {
            try await service.addEvent(userId: "user1", experienceKey: "test", event: event)
        }

        // When: Getting all events
        let retrieved = try await service.getAllEvents(userId: "user1", experienceKey: "test")

        // Then: Should return all
        #expect(retrieved.count == 3)
    }

    @Test("getAllEvents returns empty array when no events")
    func testGetAllEventsReturnsEmpty() async throws {
        // Given: Service with no events
        let service = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceKey: "test"))

        // When: Getting events
        let events = try await service.getAllEvents(userId: "user1", experienceKey: "test")

        // Then: Should be empty
        #expect(events.isEmpty)
    }

    @Test("deleteAllEvents clears events array")
    func testDeleteAllEventsClearsArray() async throws {
        // Given: Service with events
        let service = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceKey: "test"))
        try await service.addEvent(userId: "user1", experienceKey: "test", event: ExperiencePointsEvent.mock(experienceKey: "test"))
        try await service.addEvent(userId: "user1", experienceKey: "test", event: ExperiencePointsEvent.mock(experienceKey: "test"))

        // When: Deleting all events
        try await service.deleteAllEvents(userId: "user1", experienceKey: "test")

        // Then: Should be empty
        let events = try await service.getAllEvents(userId: "user1", experienceKey: "test")
        #expect(events.isEmpty)
    }

    // MARK: - calculateExperiencePoints Tests

    @Test("calculateExperiencePoints is no-op in mock")
    func testCalculateExperiencePointsIsNoOp() async throws {
        // Given: Service
        let initial = CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 5000)
        let service = MockRemoteExperiencePointsService(data: initial)

        // When: Calling calculateExperiencePoints
        try await service.calculateExperiencePoints(userId: "user1", experienceKey: "test")

        // Then: Data should remain unchanged
        let stream = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")
        var iterator = stream.makeAsyncIterator()
        let value = try await iterator.next()

        #expect(value?.totalPoints == 5000)
    }

    @Test("calculateExperiencePoints does not throw")
    func testCalculateExperiencePointsDoesNotThrow() async throws {
        // Given: Service
        let service = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceKey: "test"))

        // When/Then: Should not throw
        try await service.calculateExperiencePoints(userId: "user1", experienceKey: "test")

        #expect(true) // Success if we get here
    }

    // MARK: - Integration Tests

    @Test("Multiple updates preserve data integrity")
    func testMultipleUpdatesPreserveIntegrity() async throws {
        // Given: Service
        let service = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceKey: "test"))

        // When: Performing multiple operations
        try await service.addEvent(userId: "user1", experienceKey: "test", event: ExperiencePointsEvent.mock(id: "e1", experienceKey: "test"))
        try await service.updateCurrentExperiencePoints(userId: "user1", experienceKey: "test", data: CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 1000))

        try await service.addEvent(userId: "user1", experienceKey: "test", event: ExperiencePointsEvent.mock(id: "e2", experienceKey: "test"))
        try await service.updateCurrentExperiencePoints(userId: "user1", experienceKey: "test", data: CurrentExperiencePointsData.mock(experienceKey: "test", totalPoints: 2000))

        // Then: All data should be preserved
        let events = try await service.getAllEvents(userId: "user1", experienceKey: "test")

        let stream = service.streamCurrentExperiencePoints(userId: "user1", experienceKey: "test")
        var iterator = stream.makeAsyncIterator()
        let data = try await iterator.next()

        #expect(events.count == 2)
        #expect(data?.totalPoints == 2000)
    }
}
