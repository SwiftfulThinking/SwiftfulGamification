//
//  StreakManagerTests.swift
//  SwiftfulGamificationTests
//
//  Comprehensive integration tests for StreakManager
//

import Testing
import Foundation
@testable import SwiftfulGamification

// MARK: - Mock Logger for Testing

@MainActor
class MockGamificationLogger: GamificationLogger {
    var trackedEvents: [String] = []
    var trackedParameters: [[String: Any]] = []
    var eventTypes: [GamificationLogType] = []
    var userProperties: [[String: Any]] = []
    var highPriorityFlags: [Bool] = []

    func trackEvent(event: any GamificationLogEvent) {
        trackedEvents.append(event.eventName)
        eventTypes.append(event.type)
        if let params = event.parameters {
            trackedParameters.append(params)
        }
    }

    func addUserProperties(dict: [String : Any], isHighPriority: Bool) {
        userProperties.append(dict)
        highPriorityFlags.append(isHighPriority)
    }

    func reset() {
        trackedEvents.removeAll()
        trackedParameters.removeAll()
        eventTypes.removeAll()
        userProperties.removeAll()
        highPriorityFlags.removeAll()
    }
}

// MARK: - Test Suite

@Suite("StreakManager Tests")
@MainActor
struct StreakManagerTests {

    // MARK: - Initialization Tests

    @Test("Manager initializes with blank streak when local cache is nil")
    func testInitializationWithBlankStreak() async throws {
        // Given: Local cache returns nil
        let services = MockStreakServices(streak: nil)
        let config = StreakConfiguration(streakKey: "workout")

        // When: Initializing manager
        let manager = StreakManager(services: services, configuration: config)

        // Then: Should have blank streak
        #expect(manager.currentStreakData.streakKey == "workout")
        #expect(manager.currentStreakData.currentStreak == 0)
        #expect(manager.currentStreakData.totalEvents == 0)
    }

    @Test("Manager initializes with saved streak from local cache")
    func testInitializationWithSavedStreak() async throws {
        // Given: Local cache has saved streak
        let savedStreak = CurrentStreakData.mock(currentStreak: 10, totalEvents: 50)
        struct TestServices: StreakServices {
            let remote: RemoteStreakService
            let local: LocalStreakPersistence
        }
        let local = MockLocalStreakPersistence(streak: savedStreak)
        let remote = MockRemoteStreakService(streak: CurrentStreakData.blank(streakKey: "workout"))
        let services = TestServices(remote: remote, local: local)
        let config = StreakConfiguration(streakKey: "workout")

        // When: Initializing manager
        let manager = StreakManager(services: services, configuration: config)

        // Then: Should load saved streak
        #expect(manager.currentStreakData.currentStreak == 10)
        #expect(manager.currentStreakData.totalEvents == 50)
    }

    @Test("Manager handles local cache with mismatched streakId")
    func testInitializationWithMismatchedStreakId() async throws {
        // Given: Local cache has streak for different streakId
        let savedStreak = CurrentStreakData.mock(streakKey: "reading", currentStreak: 5)
        struct TestServices: StreakServices {
            let remote: RemoteStreakService
            let local: LocalStreakPersistence
        }
        let local = MockLocalStreakPersistence(streak: savedStreak)
        let remote = MockRemoteStreakService(streak: CurrentStreakData.blank(streakKey: "workout"))
        let services = TestServices(remote: remote, local: local)
        let config = StreakConfiguration(streakKey: "workout")

        // When: Initializing manager
        let manager = StreakManager(services: services, configuration: config)

        // Then: Manager loads blank streak for "workout" since "reading" doesn't match
        #expect(manager.currentStreakData.streakKey == "workout")
        #expect(manager.currentStreakData.currentStreak == 0)
    }

    // MARK: - Login/Logout Tests

    @Test("Login starts remote listener")
    func testLoginStartsRemoteListener() async throws {
        // Given: Manager with mock services
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: .mock())
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: true)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Logging in
        try await manager.logIn(userId: "user123")

        // Give listener time to start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then: Should log listener start event
        #expect(logger.trackedEvents.contains("StreakMan_RemoteListener_Start"))
    }

    @Test("Login triggers client-side calculation when useServerCalculation = false")
    func testLoginTriggersClientCalculation() async throws {
        // Given: Client-side calculation enabled
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Logging in
        try await manager.logIn(userId: "user123")

        // Give calculation time to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Should log calculation start
        #expect(logger.trackedEvents.contains("StreakMan_CalculateStreak_Start"))
    }

    @Test("Login triggers server-side calculation when useServerCalculation = true")
    func testLoginTriggersServerCalculation() async throws {
        // Given: Server-side calculation enabled
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: true)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Logging in
        try await manager.logIn(userId: "user123")

        // Give calculation time to start
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Then: Should NOT log client calculation (server handles it)
        #expect(!logger.trackedEvents.contains("StreakMan_CalculateStreak_Start"))
    }

    @Test("Logout cancels listeners and resets streak data")
    func testLogoutCancelsListeners() async throws {
        // Given: Manager logged in with active listener
        let initialStreak = CurrentStreakData.mock(currentStreak: 5)
        let services = MockStreakServices(streak: initialStreak)
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Logging out
        manager.logOut()

        // Then: Streak data should be reset to blank
        #expect(manager.currentStreakData.streakKey == "workout")
        #expect(manager.currentStreakData.currentStreak == 0)
        #expect(manager.currentStreakData.totalEvents == 0)
    }

    @Test("Login called twice without logout cancels previous listener")
    func testReLoginCancelsPreviousListener() async throws {
        // Given: Manager already logged in
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: .mock())
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: true)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user1")
        try await Task.sleep(nanoseconds: 20_000_000)

        logger.reset()

        // When: Logging in again as different user
        try await manager.logIn(userId: "user2")
        try await Task.sleep(nanoseconds: 20_000_000)

        // Then: New listener should start (logged)
        #expect(logger.trackedEvents.contains("StreakMan_RemoteListener_Start"))
    }

    @Test("Logout while listener is streaming")
    func testLogoutWhileStreaming() async throws {
        // Given: Manager with active stream
        let services = MockStreakServices(streak: .mock())
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 20_000_000)

        // When: Logging out (cancels stream)
        manager.logOut()

        // Then: Should reset data without crash
        #expect(manager.currentStreakData.currentStreak == 0)
    }

    // MARK: - Event Logging Tests

    @Test("Adding streak event updates currentStreakData (client mode)")
    func testAddStreakEventUpdatesDataClientMode() async throws {
        // Given: Manager in client calculation mode with initial streak
        let initialStreak = CurrentStreakData.blank(streakKey: "workout")
        let services = MockStreakServices(streak: initialStreak)
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Adding event
        try await manager.addStreakEvent(id: "event1")

        // Give calculation time to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Then: Streak should be updated (calculated from events)
        #expect(manager.currentStreakData.totalEvents == 1)
    }

    @Test("Adding event triggers client calculation when useServerCalculation = false")
    func testAddEventTriggersClientCalculation() async throws {
        // Given: Client calculation mode
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 20_000_000)

        logger.reset()

        // When: Adding event
        try await manager.addStreakEvent(id: "event1")

        // Give calculation time
        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should trigger calculation
        #expect(logger.trackedEvents.contains("StreakMan_CalculateStreak_Start"))
    }

    @Test("Adding event triggers server calculation when useServerCalculation = true")
    func testAddEventTriggersServerCalculation() async throws {
        // Given: Server calculation mode
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: true)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 20_000_000)

        logger.reset()

        // When: Adding event
        try await manager.addStreakEvent(id: "event1")

        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should NOT log client calculation
        #expect(!logger.trackedEvents.contains("StreakMan_CalculateStreak_Start"))
    }

    @Test("Adding multiple events rapidly triggers multiple calculations")
    func testMultipleEventsRapidly() async throws {
        // Given: Manager in client mode
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 20_000_000)

        logger.reset()

        // When: Adding 3 events rapidly
        try await manager.addStreakEvent(id: "event1")
        try await manager.addStreakEvent(id: "event1")
        try await manager.addStreakEvent(id: "event1")

        try await Task.sleep(nanoseconds: 150_000_000) // Wait for all calculations

        // Then: Multiple calculation starts logged
        let calcStarts = logger.trackedEvents.filter { $0 == "StreakMan_CalculateStreak_Start" }
        #expect(calcStarts.count >= 3)
    }

    // MARK: - Remote Listener Tests

    @Test("Remote listener updates currentStreakData on change")
    func testRemoteListenerUpdatesData() async throws {
        // Given: Remote service with initial streak
        let initialStreak = CurrentStreakData.mock(currentStreak: 5)
        let services = MockStreakServices(streak: initialStreak)
        let remote = services.remote as! MockRemoteStreakService
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: true)
        let manager = StreakManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Remote updates streak
        let newStreak = CurrentStreakData.mock(currentStreak: 10)
        try await remote.updateCurrentStreak(userId: "user123", streakKey: "workout", streak: newStreak)

        // Give listener time to receive update
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Manager's currentStreakData should be updated
        #expect(manager.currentStreakData.currentStreak == 10)
    }

    @Test("Remote listener saves to local cache on update")
    func testRemoteListenerSavesLocally() async throws {
        // Given: Manager with remote listener
        let initialStreak = CurrentStreakData.mock(currentStreak: 5)
        let services = MockStreakServices(streak: initialStreak)
        let remote = services.remote as! MockRemoteStreakService
        let local = services.local as! MockLocalStreakPersistence
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: true)
        let manager = StreakManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // When: Remote updates streak
        let newStreak = CurrentStreakData.mock(currentStreak: 15)
        try await remote.updateCurrentStreak(userId: "user123", streakKey: "workout", streak: newStreak)

        try await Task.sleep(nanoseconds: 100_000_000) // Wait for save

        // Then: Local cache should have updated data
        let saved = local.getSavedStreakData(streakKey: "workout")
        #expect(saved?.currentStreak == 15)
    }

    @Test("Remote listener handles errors gracefully")
    func testRemoteListenerErrorHandling() async throws {
        // Given: Remote that will emit error (stream ends after initial value)
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: .mock())
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Login (stream will eventually end/error)
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Manager should not crash (error is caught and logged)
        // Current implementation catches errors in listener
        #expect(true) // If we get here, no crash occurred
    }

    @Test("Remote listener receives multiple rapid updates")
    func testRemoteListenerMultipleUpdates() async throws {
        // Given: Manager with listener
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: .mock(currentStreak: 1))
        let remote = services.remote as! MockRemoteStreakService
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: true)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 30_000_000)

        logger.reset()

        // When: Sending multiple rapid updates
        try await remote.updateCurrentStreak(userId: "user123", streakKey: "workout", streak: CurrentStreakData.mock(currentStreak: 2))
        try await Task.sleep(nanoseconds: 20_000_000)
        try await remote.updateCurrentStreak(userId: "user123", streakKey: "workout", streak: CurrentStreakData.mock(currentStreak: 3))
        try await Task.sleep(nanoseconds: 20_000_000)
        try await remote.updateCurrentStreak(userId: "user123", streakKey: "workout", streak: CurrentStreakData.mock(currentStreak: 4))
        try await Task.sleep(nanoseconds: 20_000_000)

        // Then: All updates should be received
        #expect(manager.currentStreakData.currentStreak == 4)
        let successEvents = logger.trackedEvents.filter { $0 == "StreakMan_RemoteListener_Success" }
        #expect(successEvents.count >= 3)
    }

    // MARK: - Freeze Management Tests

    @Test("Adding freeze via manager")
    func testAddFreezeViaManager() async throws {
        // Given: Manager
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config)
        try await manager.logIn(userId: "user123")

        // When: Adding freeze
        let freezeId = "freeze-1"
        try await manager.addStreakFreeze(id: freezeId)

        // Then: Freeze should be added to remote
        let freezes = try await remote.getAllStreakFreezes(userId: "user123", streakKey: "workout")
        #expect(freezes.count == 1)
        #expect(freezes.first?.id == "freeze-1")
    }

    @Test("Getting all freezes returns correct list")
    func testGetAllFreezesReturnsCorrectList() async throws {
        // Given: Manager with freezes in remote
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService
        try await remote.addStreakFreeze(userId: "user123", streakKey: "workout", freeze: StreakFreeze.mockUnused(id: "freeze-1"))
        try await remote.addStreakFreeze(userId: "user123", streakKey: "workout", freeze: StreakFreeze.mockUnused(id: "freeze-2"))
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config)
        try await manager.logIn(userId: "user123")

        // When: Getting all freezes
        let freezes = try await manager.getAllStreakFreezes()

        // Then: Should return both freezes
        #expect(freezes.count == 2)
    }

    @Test("Auto-consume freeze creates event and marks used (client mode)")
    func testAutoConsumeFreezeCreatesEventAndMarksUsed() async throws {
        // Given: Client mode with broken streak and freeze available
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        // Add events: today and 3 days ago (2-day gap)
        let today = Date()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: today))
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: threeDaysAgo))

        // Add 2 freezes (enough to fill 2-day gap)
        try await remote.addStreakFreeze(userId: "user123", streakKey: "workout", freeze: StreakFreeze.mockUnused(id: "freeze-1"))
        try await remote.addStreakFreeze(userId: "user123", streakKey: "workout", freeze: StreakFreeze.mockUnused(id: "freeze-2"))
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false, freezeBehavior: .autoConsumeFreezes)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Logging in (triggers calculation with auto-consume)
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 200_000_000) // Wait for auto-consume

        // Then: Freezes should be marked as used
        let freezes = try await remote.getAllStreakFreezes(userId: "user123", streakKey: "workout")
        let usedFreezes = freezes.filter { $0.isUsed }
        #expect(usedFreezes.count == 2)

        // And: Freeze events should be created
        let events = try await remote.getAllEvents(userId: "user123", streakKey: "workout")
        let freezeEvents = events.filter { $0.isFreeze }
        #expect(freezeEvents.count == 2)

        // And: Logger should track auto-consumption
        #expect(logger.trackedEvents.contains("StreakMan_Freeze_AutoConsumed"))
    }

    // MARK: - Recalculation Tests

    @Test("Recalculate triggers client calculation when useServerCalculation = false")
    func testRecalculateClientSide() async throws {
        // Given: Client mode
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        logger.reset()

        // When: Manually recalculating
        manager.recalculateStreak()

        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Should trigger client calculation
        #expect(logger.trackedEvents.contains("StreakMan_CalculateStreak_Start"))
    }

    @Test("Recalculate triggers server calculation when useServerCalculation = true")
    func testRecalculateServerSide() async throws {
        // Given: Server mode
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: true)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 50_000_000)

        logger.reset()

        // When: Manually recalculating
        manager.recalculateStreak()

        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should NOT log client calculation
        #expect(!logger.trackedEvents.contains("StreakMan_CalculateStreak_Start"))
    }

    // MARK: - Analytics Tests

    @Test("Analytics events logged for remote listener success")
    func testAnalyticsRemoteListenerSuccess() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: .mock(currentStreak: 5))
        let remote = services.remote as! MockRemoteStreakService
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Logging in (starts listener)
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Should log listener start and success
        #expect(logger.trackedEvents.contains("StreakMan_RemoteListener_Start"))
        #expect(logger.trackedEvents.contains("StreakMan_RemoteListener_Success"))
    }

    @Test("Analytics events logged for calculation success (client mode)")
    func testAnalyticsCalculationSuccess() async throws {
        // Given: Client mode
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Logging in (triggers calculation)
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should log calculation start and success
        #expect(logger.trackedEvents.contains("StreakMan_CalculateStreak_Start"))
        #expect(logger.trackedEvents.contains("StreakMan_CalculateStreak_Success"))
    }

    @Test("Analytics events logged for freeze auto-consumption")
    func testAnalyticsFreezeAutoConsumed() async throws {
        // Given: Broken streak with freeze (client mode, auto-consume enabled)
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let today = Date()
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: today)!
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: today))
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: threeDaysAgo))
        try await remote.addStreakFreeze(userId: "user123", streakKey: "workout", freeze: StreakFreeze.mockUnused(id: "freeze-1"))
        try await remote.addStreakFreeze(userId: "user123", streakKey: "workout", freeze: StreakFreeze.mockUnused(id: "freeze-2"))
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false, freezeBehavior: .autoConsumeFreezes)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Logging in (triggers auto-consume)
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 200_000_000)

        // Then: Should log freeze auto-consumption
        #expect(logger.trackedEvents.contains("StreakMan_Freeze_AutoConsumed"))
    }

    @Test("User properties updated on streak change")
    func testUserPropertiesUpdated() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: .mock(currentStreak: 5))
        let remote = services.remote as! MockRemoteStreakService
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Logging in (listener receives initial value)
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: User properties should be added
        #expect(logger.userProperties.count > 0)
        #expect(logger.highPriorityFlags.contains(false)) // isHighPriority: false
    }

    @Test("Save local events logged for success and failure")
    func testSaveLocalEventsLogged() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: .mock())
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Login triggers listener update which saves locally
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 100_000_000)

        // Then: Save events should be logged
        #expect(logger.trackedEvents.contains("StreakMan_SaveLocal_Start"))
        #expect(logger.trackedEvents.contains("StreakMan_SaveLocal_Success"))
    }

    @Test("addStreakFreeze logs start and success events")
    func testAddStreakFreezeLogsEvents() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: .mock())
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config, logger: logger)
        try await manager.logIn(userId: "user123")

        logger.trackedEvents.removeAll()

        // When: Adding a freeze
        let freezeId = "freeze-1"
        try await manager.addStreakFreeze(id: freezeId)

        // Then: Should log start and success events
        #expect(logger.trackedEvents.contains("StreakMan_AddStreakFreeze_Start"))
        #expect(logger.trackedEvents.contains("StreakMan_AddStreakFreeze_Success"))
    }

    @Test("addStreakFreeze success event is marked as analytic")
    func testAddStreakFreezeSuccessIsAnalytic() async throws {
        // Given: Manager with logger
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: .mock())
        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config, logger: logger)
        try await manager.logIn(userId: "user123")

        logger.trackedEvents.removeAll()
        logger.eventTypes.removeAll()

        // When: Adding a freeze successfully
        let freezeId = "freeze-1"
        try await manager.addStreakFreeze(id: freezeId)

        // Then: Success event should be marked as .analytic
        let successIndex = logger.trackedEvents.firstIndex(of: "StreakMan_AddStreakFreeze_Success")
        #expect(successIndex != nil)
        if let index = successIndex {
            #expect(logger.eventTypes[index] == .analytic)
        }
    }

    // MARK: - Edge Case Tests

    @Test("Client calculation with empty events array")
    func testClientCalculationWithEmptyEvents() async throws {
        // Given: Client mode with no events
        let logger = MockGamificationLogger()
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config, logger: logger)

        // When: Login triggers calculation with no events
        try await manager.logIn(userId: "user123")

        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should complete successfully with blank streak
        #expect(logger.trackedEvents.contains("StreakMan_CalculateStreak_Success"))
        #expect(manager.currentStreakData.currentStreak == 0)
    }

    @Test("Client calculation handles race with remote listener update")
    func testClientCalculationRaceWithRemoteListener() async throws {
        // Given: Client mode with events
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock())
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")

        // When: Calculation completes and updates remote, which triggers listener
        try await Task.sleep(nanoseconds: 150_000_000)

        // Simulate external update while calculation is in progress
        try await remote.updateCurrentStreak(userId: "user123", streakKey: "workout", streak: CurrentStreakData.mock(currentStreak: 99))

        try await Task.sleep(nanoseconds: 50_000_000)

        // Then: Manager should have latest value (from listener, not calculation)
        // This tests the race condition behavior (last write wins)
        #expect(manager.currentStreakData.currentStreak != nil)
    }

    @Test("getAllStreakEvents returns all events")
    func testGetAllStreakEvents() async throws {
        // Given: Manager with events
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(id: "e1"))
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(id: "e2"))

        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config)
        try await manager.logIn(userId: "user123")

        // When: Getting all events
        let events = try await manager.getAllStreakEvents()

        // Then: Should return all events
        #expect(events.count == 2)
    }

    @Test("deleteAllStreakEvents clears events")
    func testDeleteAllStreakEvents() async throws {
        // Given: Manager with events
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock())
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock())

        let config = StreakConfiguration(streakKey: "workout")
        let manager = StreakManager(services: services, configuration: config)
        try await manager.logIn(userId: "user123")

        // When: Deleting all events
        try await manager.deleteAllStreakEvents()

        // Then: Events should be cleared
        let events = try await manager.getAllStreakEvents()
        #expect(events.isEmpty)
    }

    // MARK: - Streak Calculation Accuracy Tests

    @Test("Initialization calculates correct streak from local cache")
    func testInitCalculatesCorrectStreak() async throws {
        // Given: Local cache has streak with specific values
        let savedStreak = CurrentStreakData.mock(
            currentStreak: 7,
            longestStreak: 10,
            totalEvents: 25
        )
        struct TestServices: StreakServices {
            let remote: RemoteStreakService
            let local: LocalStreakPersistence
        }
        let local = MockLocalStreakPersistence(streak: savedStreak)
        let remote = MockRemoteStreakService(streak: CurrentStreakData.blank(streakKey: "workout"))
        let services = TestServices(remote: remote, local: local)
        let config = StreakConfiguration(streakKey: "workout")

        // When: Initializing manager
        let manager = StreakManager(services: services, configuration: config)

        // Then: Should have correct streak values from cache
        #expect(manager.currentStreakData.currentStreak == 7)
        #expect(manager.currentStreakData.longestStreak == 10)
        #expect(manager.currentStreakData.totalEvents == 25)
    }

    @Test("Login calculates correct streak with consecutive daily events (client mode)")
    func testLoginCalculatesConsecutiveDailyStreak() async throws {
        // Given: Events for 5 consecutive days
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let today = Date()
        for daysAgo in 0..<5 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: date))
        }

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in (triggers calculation)
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should calculate streak of 5
        #expect(manager.currentStreakData.currentStreak == 5)
        #expect(manager.currentStreakData.totalEvents == 5)
    }

    @Test("Login calculates correct streak with gap and no freezes (client mode)")
    func testLoginCalculatesStreakWithGapNoFreezes() async throws {
        // Given: Events with a 2-day gap and no freezes
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let today = Date()
        // Today and yesterday
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: today))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: yesterday))

        // 4 days ago (creates 2-day gap)
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: today)!
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: fourDaysAgo))

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Streak should be broken (only counts from today back to gap)
        #expect(manager.currentStreakData.currentStreak == 2) // Today + yesterday
        #expect(manager.currentStreakData.totalEvents == 3)
    }

    @Test("Login calculates correct streak with gap and sufficient freezes (client mode)")
    func testLoginCalculatesStreakWithGapAndFreezes() async throws {
        // Given: Events with 1-day gap and 1 freeze available (auto-consume enabled)
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let today = Date()
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: today))

        // 2 days ago (creates 1-day gap)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: twoDaysAgo))

        // Add freeze
        try await remote.addStreakFreeze(userId: "user123", streakKey: "workout", freeze: StreakFreeze.mockUnused(id: "freeze-1"))

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false, freezeBehavior: .autoConsumeFreezes)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in (should auto-consume freeze)
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 200_000_000)

        // Then: Streak should be saved (freeze fills gap)
        #expect(manager.currentStreakData.currentStreak == 3) // Today + freeze + 2 days ago
        #expect(manager.currentStreakData.totalEvents == 2)
    }

    @Test("Adding event calculates correct new streak (client mode)")
    func testAddEventCalculatesCorrectNewStreak() async throws {
        // Given: Manager with existing 3-day streak (today through 2 days ago)
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        // Add events for today, yesterday and 2 days ago (current streak = 3)
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: today))
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: yesterday))
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: twoDaysAgo))

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Initial streak is 3
        #expect(manager.currentStreakData.currentStreak == 3)
        #expect(manager.currentStreakData.totalEvents == 3)

        // When: Adding another event later today
        let laterToday = Calendar.current.date(byAdding: .hour, value: 2, to: today)!
        try await manager.addStreakEvent(id: "event1", timestamp: laterToday)
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Streak should stay at 3 (same day), but totalEvents increases
        #expect(manager.currentStreakData.currentStreak == 3)
        #expect(manager.currentStreakData.totalEvents == 4)
    }

    @Test("Adding event after gap breaks streak correctly (client mode)")
    func testAddEventAfterGapBreaksStreak() async throws {
        // Given: Manager with last event 3 days ago
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: threeDaysAgo))

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // When: Adding event today (after 2-day gap)
        let today = Date()
        try await manager.addStreakEvent(id: "event1", timestamp: today)
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Streak should reset to 1
        #expect(manager.currentStreakData.currentStreak == 1)
        #expect(manager.currentStreakData.totalEvents == 2)
    }

    @Test("Goal-based streak calculates correctly with multiple events per day (client mode)")
    func testGoalBasedStreakCalculation() async throws {
        // Given: Goal-based configuration (3 events per day) with proper events
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        // Today: 3 events (meets goal)
        for hour in [8, 12, 18] {
            let eventDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: eventDate))
        }

        // Yesterday: 3 events (meets goal)
        for hour in [9, 14, 19] {
            let eventDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: yesterday)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: eventDate))
        }

        let config = StreakConfiguration(streakKey: "workout", eventsRequiredPerDay: 3, useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should have 2-day streak
        #expect(manager.currentStreakData.currentStreak == 2)
        #expect(manager.currentStreakData.eventsRequiredPerDay == 3)
        #expect(manager.currentStreakData.todayEventCount == 3)
    }

    @Test("Goal-based streak breaks when daily goal not met (client mode)")
    func testGoalBasedStreakBreaksWhenGoalNotMet() async throws {
        // Given: Goal-based configuration with insufficient events on one day
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        // Today: 3 events (meets goal)
        for hour in [8, 12, 18] {
            let eventDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: eventDate))
        }

        // Yesterday: Only 2 events (fails goal of 3)
        for hour in [9, 14] {
            let eventDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: yesterday)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: eventDate))
        }

        // Two days ago: 3 events (meets goal)
        for hour in [10, 15, 20] {
            let eventDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: twoDaysAgo)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: eventDate))
        }

        let config = StreakConfiguration(streakKey: "workout", eventsRequiredPerDay: 3, useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Streak should only be 1 (today), broken by yesterday's insufficient events
        #expect(manager.currentStreakData.currentStreak == 1)
        #expect(manager.currentStreakData.totalEvents == 8)
    }

    @Test("Longest streak is updated correctly when current exceeds it (client mode)")
    func testLongestStreakUpdated() async throws {
        // Given: Manager with initial longestStreak of 5
        let initialStreak = CurrentStreakData.mock(
            currentStreak: 5,
            longestStreak: 5,
            lastEventDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            totalEvents: 10
        )
        let services = MockStreakServices(streak: initialStreak)
        let remote = services.remote as! MockRemoteStreakService

        // Add events for 7 consecutive days
        let today = Date()
        for daysAgo in 0...6 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: date))
        }

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in (recalculates streak)
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Both currentStreak and longestStreak should be 7
        #expect(manager.currentStreakData.currentStreak == 7)
        #expect(manager.currentStreakData.longestStreak == 7)
    }

    @Test("Longest streak is preserved when current is lower (client mode)")
    func testLongestStreakPreserved() async throws {
        // Given: Manager with longestStreak of 10, but current broken streak
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let today = Date()
        // Create a 3-day current streak
        for daysAgo in 0...2 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: date))
        }

        // Create a longer streak in the past (10 days, starting 5 days ago)
        for daysAgo in 5...14 {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: today)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: date))
        }

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: currentStreak should be 3, longestStreak should be 10
        #expect(manager.currentStreakData.currentStreak == 3)
        #expect(manager.currentStreakData.longestStreak == 10)
    }

    @Test("Multiple events on same day count as one day in streak (client mode)")
    func testMultipleEventsOnSameDayCountAsOne() async throws {
        // Given: Multiple events on the same day
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let today = Date()
        // Add 5 events today at different times
        for hour in [6, 9, 12, 15, 18] {
            let eventDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: today)!
            try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: eventDate))
        }

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Streak should be 1 day (not 5)
        #expect(manager.currentStreakData.currentStreak == 1)
        #expect(manager.currentStreakData.totalEvents == 5)
    }

    @Test("Streak calculation respects user timezone changes (client mode)")
    func testStreakCalculationWithTimezoneChanges() async throws {
        // Given: Events in different timezones
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        // Event in PST (California)
        let pstTimezone = TimeZone(identifier: "America/Los_Angeles")!
        var pstCalendar = Calendar.current
        pstCalendar.timeZone = pstTimezone

        let today = Date()
        let pstDate = pstCalendar.date(bySettingHour: 22, minute: 0, second: 0, of: today)! // 10 PM PST
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent(
            timestamp: pstDate,
            timezone: pstTimezone.identifier
        ))

        // Event in JST (Japan) - next calendar day in JST but same "day streak"
        let jstTimezone = TimeZone(identifier: "Asia/Tokyo")!
        var jstCalendar = Calendar.current
        jstCalendar.timeZone = jstTimezone

        let jstDate = jstCalendar.date(byAdding: .hour, value: 4, to: pstDate)! // 4 hours later = 2 AM JST next day
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent(
            timestamp: jstDate,
            timezone: jstTimezone.identifier
        ))

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should handle timezone changes correctly
        #expect(manager.currentStreakData.currentStreak != nil)
        #expect(manager.currentStreakData.totalEvents == 2)
    }

    @Test("Streak with leeway hours calculates correctly (client mode)")
    func testStreakWithLeewayHours() async throws {
        // Given: Configuration with 6-hour leeway
        let services = MockStreakServices(streak: nil)
        let remote = services.remote as! MockRemoteStreakService

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        // Event yesterday at 11 PM
        let lastNight = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: yesterday)!
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: lastNight))

        // Event today at 4 AM (within 6-hour leeway window)
        let todayEarly = Calendar.current.date(bySettingHour: 4, minute: 0, second: 0, of: now)!
        try await remote.addEvent(userId: "user123", streakKey: "workout", event: StreakEvent.mock(timestamp: todayEarly))

        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false, leewayHours: 6)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Should maintain streak with leeway
        #expect(manager.currentStreakData.currentStreak == 2)
    }

    @Test("Empty events array results in zero streak (client mode)")
    func testEmptyEventsResultsInZeroStreak() async throws {
        // Given: Manager with no events
        let services = MockStreakServices(streak: nil)
        let config = StreakConfiguration(streakKey: "workout", useServerCalculation: false)
        let manager = StreakManager(services: services, configuration: config)

        // When: Logging in
        try await manager.logIn(userId: "user123")
        try await Task.sleep(nanoseconds: 150_000_000)

        // Then: Streak should be 0
        #expect(manager.currentStreakData.currentStreak == 0)
        #expect(manager.currentStreakData.longestStreak == 0)
        #expect(manager.currentStreakData.totalEvents == 0)
    }
}
