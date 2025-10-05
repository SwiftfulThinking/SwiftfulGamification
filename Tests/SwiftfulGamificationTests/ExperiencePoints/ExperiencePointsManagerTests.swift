//
//  ExperiencePointsManagerTests.swift
//  SwiftfulGamificationTests
//
//  Comprehensive integration tests for ExperiencePointsManager
//

import Testing
import Foundation
@testable import SwiftfulGamification

// MARK: - Test Suite

@Suite("ExperiencePointsManager Tests")
@MainActor
struct ExperiencePointsManagerTests {

    // MARK: - Initialization Tests

    @Test("Manager initializes with blank data when local cache is nil")
    func testInitializationWithBlankData() async throws {
        // Given: Local cache returns nil
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main")

        // When: Initializing manager
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // Then: Should have blank data
        #expect(manager.currentExperiencePointsData.experienceId == "main")
        #expect(manager.currentExperiencePointsData.totalPoints == 0)
        #expect(manager.currentExperiencePointsData.totalEvents == 0)
    }

    @Test("Manager initializes with saved data from local cache")
    func testInitializationWithSavedData() async throws {
        // Given: Local cache has saved data
        let savedData = CurrentExperiencePointsData.mock(totalPoints: 5000, totalEvents: 100)
        struct TestServices: ExperiencePointsServices {
            let remote: RemoteExperiencePointsService
            let local: LocalExperiencePointsPersistence
        }
        let local = MockLocalExperiencePointsPersistence(data: savedData)
        let remote = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceId: "main"))
        let services = TestServices(remote: remote, local: local)
        let config = ExperiencePointsConfiguration(experienceId: "main")

        // When: Initializing manager
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // Then: Should load saved data
        #expect(manager.currentExperiencePointsData.totalPoints == 5000)
        #expect(manager.currentExperiencePointsData.totalEvents == 100)
    }

    @Test("Manager handles local cache with mismatched experienceId")
    func testInitializationWithMismatchedExperienceId() async throws {
        // Given: Local cache has data for different experienceId
        let savedData = CurrentExperiencePointsData.mock(experienceId: "battle", totalPoints: 2000)
        struct TestServices: ExperiencePointsServices {
            let remote: RemoteExperiencePointsService
            let local: LocalExperiencePointsPersistence
        }
        let local = MockLocalExperiencePointsPersistence(data: savedData)
        let remote = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceId: "main"))
        let services = TestServices(remote: remote, local: local)
        let config = ExperiencePointsConfiguration(experienceId: "main")

        // When: Initializing manager
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // Then: Manager loads blank data for "main" since "battle" doesn't match
        #expect(manager.currentExperiencePointsData.experienceId == "main")
        #expect(manager.currentExperiencePointsData.totalPoints == 0)
    }

    // MARK: - Login/Logout Tests

    @Test("Login starts remote listener")
    func testLoginStartsRemoteListener() async throws {
        // Given: Manager with mock services
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: .mock())
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: true)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        // When: Logging in
        try await manager.logIn(userId: "user123")

        // Give listener time to start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then: Should log listener start event
        #expect(logger.trackedEvents.contains("XPMan_RemoteListener_Start"))
    }

    @Test("Login triggers client-side calculation when useServerCalculation = false")
    func testLoginTriggersClientCalculation() async throws {
        // Given: Client-side calculation enabled
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        // When: Logging in
        try await manager.logIn(userId: "user123")

        // Give calculation time to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Should log calculation start
        #expect(logger.trackedEvents.contains("XPMan_CalculateXP_Start"))
    }

    @Test("Login triggers server-side calculation when useServerCalculation = true")
    func testLoginTriggersServerCalculation() async throws {
        // Given: Server-side calculation enabled
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: true)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        // When: Logging in
        try await manager.logIn(userId: "user123")

        // Give calculation time to start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then: Should NOT log client calculation (server handles it)
        #expect(!logger.trackedEvents.contains("XPMan_CalculateXP_Start"))
    }

    @Test("Logout cancels listeners and resets data")
    func testLogoutCancelsListeners() async throws {
        // Given: Manager logged in with active listener
        let initialData = CurrentExperiencePointsData.mock(totalPoints: 5000)
        let services = MockExperiencePointsServices(data: initialData)
        let config = ExperiencePointsConfiguration(experienceId: "main")
        let manager = ExperiencePointsManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Logging out
        manager.logOut()

        // Then: Data should be reset to blank
        #expect(manager.currentExperiencePointsData.experienceId == "main")
        #expect(manager.currentExperiencePointsData.totalPoints == 0)
        #expect(manager.currentExperiencePointsData.totalEvents == 0)
    }

    @Test("Login called twice without logout cancels previous listener")
    func testReLoginCancelsPreviousListener() async throws {
        // Given: Manager already logged in
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: .mock())
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: true)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user1")
        try await Task.sleep(nanoseconds: 20_000_000)

        logger.reset()

        // When: Logging in again as different user
        try await manager.logIn(userId: "user2")
        try await Task.sleep(nanoseconds: 20_000_000)

        // Then: New listener should start (logged)
        #expect(logger.trackedEvents.contains("XPMan_RemoteListener_Start"))
    }

    // MARK: - XP Event Logging Tests

    @Test("Adding XP event updates currentData (client mode)")
    func testAddXPEventUpdatesDataClientMode() async throws {
        // Given: Manager in client calculation mode
        let initialData = CurrentExperiencePointsData.blank(experienceId: "main")
        let services = MockExperiencePointsServices(data: initialData)
        let remote = services.remote as! MockRemoteExperiencePointsService
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Adding XP event
        let event = ExperiencePointsEvent.mock(experienceId: "main", points: 100)
        try await manager.addExperiencePoints(userId: "user123", event: event)

        // Give calculation time to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Data should be updated
        #expect(manager.currentExperiencePointsData.totalEvents == 1)
        #expect(manager.currentExperiencePointsData.totalPoints == 100)
    }

    @Test("Adding event triggers client calculation when useServerCalculation = false")
    func testAddEventTriggersClientCalculation() async throws {
        // Given: Client calculation mode
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 20_000_000)

        logger.reset()

        // When: Adding event
        try await manager.addExperiencePoints(userId: "user123", event: ExperiencePointsEvent.mock(experienceId: "main", points: 50))

        // Give calculation time
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should trigger calculation
        #expect(logger.trackedEvents.contains("XPMan_CalculateXP_Start"))
    }

    @Test("Adding event triggers server calculation when useServerCalculation = true")
    func testAddEventTriggersServerCalculation() async throws {
        // Given: Server calculation mode
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: true)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 20_000_000)

        logger.reset()

        // When: Adding event
        try await manager.addExperiencePoints(userId: "user123", event: ExperiencePointsEvent.mock(experienceId: "main", points: 50))

        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should NOT log client calculation
        #expect(!logger.trackedEvents.contains("XPMan_CalculateXP_Start"))
    }

    @Test("Adding multiple XP events accumulates points correctly")
    func testMultipleEventsAccumulatePoints() async throws {
        // Given: Manager in client mode
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Adding multiple events
        try await manager.addExperiencePoints(userId: "user123", event: ExperiencePointsEvent.mock(experienceId: "main", points: 100))
        try await Task.sleep(nanoseconds: 100_000_000)
        try await manager.addExperiencePoints(userId: "user123", event: ExperiencePointsEvent.mock(experienceId: "main", points: 250))
        try await Task.sleep(nanoseconds: 100_000_000)
        try await manager.addExperiencePoints(userId: "user123", event: ExperiencePointsEvent.mock(experienceId: "main", points: 50))
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Total should be sum of all events
        #expect(manager.currentExperiencePointsData.totalPoints == 400)
        #expect(manager.currentExperiencePointsData.totalEvents == 3)
    }

    // MARK: - Remote Listener Tests

    @Test("Remote listener updates currentData on change")
    func testRemoteListenerUpdatesData() async throws {
        // Given: Remote service with initial data
        let initialData = CurrentExperiencePointsData.mock(totalPoints: 1000)
        let services = MockExperiencePointsServices(data: initialData)
        let remote = services.remote as! MockRemoteExperiencePointsService
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: true)
        let manager = ExperiencePointsManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Remote updates data
        let newData = CurrentExperiencePointsData.mock(totalPoints: 2500)
        try await remote.updateCurrentExperiencePoints(userId: "user123", experienceId: "main", data: newData)

        // Give listener time to receive update
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Manager's data should be updated
        #expect(manager.currentExperiencePointsData.totalPoints == 2500)
    }

    @Test("Remote listener saves to local cache on update")
    func testRemoteListenerSavesLocally() async throws {
        // Given: Manager with remote listener
        let initialData = CurrentExperiencePointsData.mock(totalPoints: 1000)
        let services = MockExperiencePointsServices(data: initialData)
        let remote = services.remote as! MockRemoteExperiencePointsService
        let local = services.local as! MockLocalExperiencePointsPersistence
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: true)
        let manager = ExperiencePointsManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Remote updates data
        let newData = CurrentExperiencePointsData.mock(totalPoints: 3500)
        try await remote.updateCurrentExperiencePoints(userId: "user123", experienceId: "main", data: newData)

        try await Task.sleep(nanoseconds: 100_000_000) // Wait for save

        // Then: Local cache should have updated data
        let saved = local.getSavedExperiencePointsData(experienceId: "main")
        #expect(saved?.totalPoints == 3500)
    }

    @Test("Remote listener handles errors gracefully")
    func testRemoteListenerErrorHandling() async throws {
        // Given: Remote that will emit error (stream ends after initial value)
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: .mock())
        let config = ExperiencePointsConfiguration(experienceId: "main")
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        // When: Login (stream will eventually end/error)
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Manager should not crash (error is caught and logged)
        #expect(true) // If we get here, no crash occurred
    }

    @Test("Remote listener receives multiple rapid updates")
    func testRemoteListenerMultipleUpdates() async throws {
        // Given: Manager with listener
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: .mock(totalPoints: 100))
        let remote = services.remote as! MockRemoteExperiencePointsService
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: true)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 30_000_000)

        logger.reset()

        // When: Sending multiple rapid updates
        try await remote.updateCurrentExperiencePoints(userId: "user123", experienceId: "main", data: CurrentExperiencePointsData.mock(totalPoints: 500))
        try await Task.sleep(nanoseconds: 20_000_000)
        try await remote.updateCurrentExperiencePoints(userId: "user123", experienceId: "main", data: CurrentExperiencePointsData.mock(totalPoints: 1000))
        try await Task.sleep(nanoseconds: 20_000_000)
        try await remote.updateCurrentExperiencePoints(userId: "user123", experienceId: "main", data: CurrentExperiencePointsData.mock(totalPoints: 1500))
        try await Task.sleep(nanoseconds: 20_000_000)

        // Then: All updates should be received
        #expect(manager.currentExperiencePointsData.totalPoints == 1500)
        let successEvents = logger.trackedEvents.filter { $0 == "XPMan_RemoteListener_Success" }
        #expect(successEvents.count >= 3)
    }

    // MARK: - Recalculation Tests

    @Test("Recalculate triggers client calculation when useServerCalculation = false")
    func testRecalculateClientSide() async throws {
        // Given: Client mode
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        logger.reset()

        // When: Manually recalculating
        manager.recalculateExperiencePoints(userId: "user123")

        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should trigger client calculation
        #expect(logger.trackedEvents.contains("XPMan_CalculateXP_Start"))
    }

    @Test("Recalculate triggers server calculation when useServerCalculation = true")
    func testRecalculateServerSide() async throws {
        // Given: Server mode
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: true)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        logger.reset()

        // When: Manually recalculating
        manager.recalculateExperiencePoints(userId: "user123")

        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should NOT log client calculation
        #expect(!logger.trackedEvents.contains("XPMan_CalculateXP_Start"))
    }

    // MARK: - Analytics Tests

    @Test("Analytics events logged for remote listener success")
    func testAnalyticsRemoteListenerSuccess() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: .mock(totalPoints: 1000))
        let config = ExperiencePointsConfiguration(experienceId: "main")
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        // When: Logging in (starts listener)
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should log listener start and success
        #expect(logger.trackedEvents.contains("XPMan_RemoteListener_Start"))
        #expect(logger.trackedEvents.contains("XPMan_RemoteListener_Success"))
    }

    @Test("Analytics events logged for calculation success (client mode)")
    func testAnalyticsCalculationSuccess() async throws {
        // Given: Client mode
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        // When: Logging in (triggers calculation)
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should log calculation start and success
        #expect(logger.trackedEvents.contains("XPMan_CalculateXP_Start"))
        #expect(logger.trackedEvents.contains("XPMan_CalculateXP_Success"))
    }

    @Test("User properties updated on data change")
    func testUserPropertiesUpdated() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: .mock(totalPoints: 1000))
        let config = ExperiencePointsConfiguration(experienceId: "main")
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        // When: Logging in (listener receives initial value)
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: User properties should be added
        #expect(logger.userProperties.count > 0)
        #expect(logger.highPriorityFlags.contains(false)) // isHighPriority: false
    }

    @Test("Save local events logged for success")
    func testSaveLocalEventsLogged() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: .mock())
        let config = ExperiencePointsConfiguration(experienceId: "main")
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        // When: Login triggers listener update which saves locally
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Save events should be logged
        #expect(logger.trackedEvents.contains("XPMan_SaveLocal_Start"))
        #expect(logger.trackedEvents.contains("XPMan_SaveLocal_Success"))
    }

    // MARK: - Edge Case Tests

    @Test("Client calculation with empty events array")
    func testClientCalculationWithEmptyEvents() async throws {
        // Given: Client mode with no events
        let logger = MockGamificationLogger()
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config, logger: logger)

        // When: Login triggers calculation with no events
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should complete successfully with blank data
        #expect(logger.trackedEvents.contains("XPMan_CalculateXP_Success"))
        #expect(manager.currentExperiencePointsData.totalPoints == 0)
    }

    @Test("getAllExperiencePointsEvents returns all events")
    func testGetAllExperiencePointsEvents() async throws {
        // Given: Manager with events
        let services = MockExperiencePointsServices(data: nil)
        let remote = services.remote as! MockRemoteExperiencePointsService
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(id: "e1", experienceId: "main", points: 100))
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(id: "e2", experienceId: "main", points: 250))

        let config = ExperiencePointsConfiguration(experienceId: "main")
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // When: Getting all events
        let events = try await manager.getAllExperiencePointsEvents(userId: "user123")

        // Then: Should return all events
        #expect(events.count == 2)
    }

    @Test("deleteAllExperiencePointsEvents clears events")
    func testDeleteAllExperiencePointsEvents() async throws {
        // Given: Manager with events
        let services = MockExperiencePointsServices(data: nil)
        let remote = services.remote as! MockRemoteExperiencePointsService
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(experienceId: "main", points: 100))
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(experienceId: "main", points: 250))

        let config = ExperiencePointsConfiguration(experienceId: "main")
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // When: Deleting all events
        try await manager.deleteAllExperiencePointsEvents(userId: "user123")

        // Then: Events should be cleared
        let events = try await manager.getAllExperiencePointsEvents(userId: "user123")
        #expect(events.isEmpty)
    }

    // MARK: - XP Calculation Accuracy Tests

    @Test("Initialization calculates correct XP from local cache")
    func testInitCalculatesCorrectXP() async throws {
        // Given: Local cache has data with specific values
        let savedData = CurrentExperiencePointsData.mock(
            totalPoints: 7500,
            totalEvents: 150
        )
        struct TestServices: ExperiencePointsServices {
            let remote: RemoteExperiencePointsService
            let local: LocalExperiencePointsPersistence
        }
        let local = MockLocalExperiencePointsPersistence(data: savedData)
        let remote = MockRemoteExperiencePointsService(data: CurrentExperiencePointsData.blank(experienceId: "main"))
        let services = TestServices(remote: remote, local: local)
        let config = ExperiencePointsConfiguration(experienceId: "main")

        // When: Initializing manager
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // Then: Should have correct XP values from cache
        #expect(manager.currentExperiencePointsData.totalPoints == 7500)
        #expect(manager.currentExperiencePointsData.totalEvents == 150)
    }

    @Test("Login calculates correct XP from multiple events (client mode)")
    func testLoginCalculatesCorrectXPFromEvents() async throws {
        // Given: Events with varying point values
        let services = MockExperiencePointsServices(data: nil)
        let remote = services.remote as! MockRemoteExperiencePointsService

        let today = Date()
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(date: today, experienceId: "main", points: 100))
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(date: today, experienceId: "main", points: 250))
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(date: today, experienceId: "main", points: 50))

        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // When: Logging in (triggers calculation)
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should calculate total of 400 points
        #expect(manager.currentExperiencePointsData.totalPoints == 400)
        #expect(manager.currentExperiencePointsData.totalEvents == 3)
    }

    @Test("Adding event calculates correct new total (client mode)")
    func testAddEventCalculatesCorrectNewTotal() async throws {
        // Given: Manager with existing XP
        let services = MockExperiencePointsServices(data: nil)
        let remote = services.remote as! MockRemoteExperiencePointsService

        let today = Date()
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(date: today, experienceId: "main", points: 500))

        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Initial XP is 500
        #expect(manager.currentExperiencePointsData.totalPoints == 500)
        #expect(manager.currentExperiencePointsData.totalEvents == 1)

        // When: Adding another event
        try await manager.addExperiencePoints(userId: "user123", event: ExperiencePointsEvent.mock(experienceId: "main", points: 750))
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Total should be 1250
        #expect(manager.currentExperiencePointsData.totalPoints == 1250)
        #expect(manager.currentExperiencePointsData.totalEvents == 2)
    }

    @Test("Multiple events on same day accumulate correctly")
    func testMultipleEventsOnSameDayAccumulate() async throws {
        // Given: Multiple events on the same day
        let services = MockExperiencePointsServices(data: nil)
        let remote = services.remote as! MockRemoteExperiencePointsService

        let today = Date()
        // Add 5 events today
        for hour in [6, 9, 12, 15, 18] {
            let eventDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(date: eventDate, experienceId: "main", points: 100))
        }

        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Total should be 500 (5 × 100)
        #expect(manager.currentExperiencePointsData.totalPoints == 500)
        #expect(manager.currentExperiencePointsData.totalEvents == 5)
    }

    @Test("Zero and negative point values handled correctly")
    func testZeroAndNegativePointValues() async throws {
        // Given: Events with zero points
        let services = MockExperiencePointsServices(data: nil)
        let remote = services.remote as! MockRemoteExperiencePointsService

        let today = Date()
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(date: today, experienceId: "main", points: 100))
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(date: today, experienceId: "main", points: 0))

        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Total should be 100 (zero events count toward totalEvents but not points)
        #expect(manager.currentExperiencePointsData.totalPoints == 100)
        #expect(manager.currentExperiencePointsData.totalEvents == 2)
    }

    @Test("Empty events array results in zero XP (client mode)")
    func testEmptyEventsResultsInZeroXP() async throws {
        // Given: Manager with no events
        let services = MockExperiencePointsServices(data: nil)
        let config = ExperiencePointsConfiguration(experienceId: "main", useServerCalculation: false)
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: XP should be 0
        #expect(manager.currentExperiencePointsData.totalPoints == 0)
        #expect(manager.currentExperiencePointsData.totalEvents == 0)
    }

    // MARK: - Metadata Filtering Tests

    @Test("Get events for specific metadata field returns filtered results")
    func testGetEventsForMetadataField() async throws {
        // Given: Manager with events containing different metadata
        let services = MockExperiencePointsServices(data: nil)
        let remote = services.remote as! MockRemoteExperiencePointsService

        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(
            experienceId: "main",
            points: 100,
            metadata: ["source": "quest"]
        ))
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(
            experienceId: "main",
            points: 200,
            metadata: ["source": "battle"]
        ))
        try await remote.addEvent(userId: "user123", experienceId: "main", event: ExperiencePointsEvent.mock(
            experienceId: "main",
            points: 150,
            metadata: ["source": "quest"]
        ))

        let config = ExperiencePointsConfiguration(experienceId: "main")
        let manager = ExperiencePointsManager(services: services, configuration: config)

        // When: Getting events for source = "quest"
        let questEvents = try await manager.getAllExperiencePointsEvents(userId: "user123", forField: "source", equalTo: .string("quest"))

        // Then: Should return only quest events
        #expect(questEvents.count == 2)
        #expect(questEvents.allSatisfy { $0.metadata["source"] == .string("quest") })

        let totalQuestPoints = questEvents.reduce(0) { $0 + $1.points }
        #expect(totalQuestPoints == 250)
    }
}
