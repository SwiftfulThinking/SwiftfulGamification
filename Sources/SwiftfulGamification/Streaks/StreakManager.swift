import Foundation
import Observation

@MainActor
@Observable
public class StreakManager {
    private let logger: GamificationLogger?
    private let remote: RemoteStreakService
    private let local: LocalStreakPersistence
    internal let configuration: StreakConfiguration

    public private(set) var currentStreakData: CurrentStreakData
    private var currentStreakListenerTask: Task<Void, Error>?

    private var userId: String? {
        currentStreakData.userId
    }

    public init(
        services: StreakServices,
        configuration: StreakConfiguration,
        logger: GamificationLogger? = nil
    ) {
        self.remote = services.remote
        self.local = services.local
        self.configuration = configuration
        self.logger = logger
        self.currentStreakData = local.getSavedStreakData(streakKey: configuration.streakKey) ?? CurrentStreakData.blank(streakKey: configuration.streakKey)
    }

    // MARK: - Public API

    public func logIn(userId: String) async throws {
        // If userId is changing, log out first to clean up old listeners
        if self.userId != userId {
            logOut()
        }

        if currentStreakData.userId != userId {
            currentStreakData = currentStreakData.updatingUserId(userId)
        }

        addCurrentStreakListener(userId: userId)
        calculateStreak(userId: userId)
    }

    public func logOut() {
        currentStreakListenerTask?.cancel()
        currentStreakListenerTask = nil
        let blank = CurrentStreakData.blank(streakKey: configuration.streakKey)
        try? local.saveCurrentStreakData(streakKey: configuration.streakKey, blank)
        currentStreakData = blank
    }

    private func addCurrentStreakListener(userId: String) {
        logger?.trackEvent(event: Event.remoteListenerStart)

        currentStreakListenerTask?.cancel()
        currentStreakListenerTask = Task {
            do {
                for try await value in remote.streamCurrentStreak(userId: userId, streakKey: configuration.streakKey) {
                    // Always preserve userId from logIn (ensure consistency)
                    let updatedValue = value.userId != userId ? value.updatingUserId(userId) : value
                    self.currentStreakData = updatedValue
                    logger?.trackEvent(event: Event.remoteListenerSuccess(streak: updatedValue))
                    logger?.addUserProperties(dict: updatedValue.eventParameters, isHighPriority: false)
                    self.saveCurrentStreakLocally()
                }
            } catch {
                logger?.trackEvent(event: Event.remoteListenerFail(error: error))
            }
        }
    }

    private func saveCurrentStreakLocally() {
        logger?.trackEvent(event: Event.saveLocalStart(streak: currentStreakData))

        Task {
            do {
                try local.saveCurrentStreakData(streakKey: configuration.streakKey, currentStreakData)
                logger?.trackEvent(event: Event.saveLocalSuccess(streak: currentStreakData))
            } catch {
                logger?.trackEvent(event: Event.saveLocalFail(error: error))
            }
        }
    }

    @discardableResult
    public func addStreakEvent(
        id: String,
        timestamp: Date = Date(),
        metadata: [String: GamificationDictionaryValue] = [:]
    ) async throws -> StreakEvent {
        guard let userId = userId else {
            throw StreakError.notLoggedIn
        }

        let event = StreakEvent(
            id: id,
            timestamp: timestamp,
            timezone: TimeZone.current.identifier,
            isFreeze: false,
            freezeId: nil,
            metadata: metadata
        )
        try await remote.addEvent(userId: userId, streakKey: configuration.streakKey, event: event)
        calculateStreak(userId: userId)
        return event
    }

    public func getAllStreakEvents() async throws -> [StreakEvent] {
        guard let userId = userId else {
            throw StreakError.notLoggedIn
        }
        return try await remote.getAllEvents(userId: userId, streakKey: configuration.streakKey)
    }

    public func deleteAllStreakEvents() async throws {
        guard let userId = userId else {
            throw StreakError.notLoggedIn
        }
        try await remote.deleteAllEvents(userId: userId, streakKey: configuration.streakKey)
    }

    // MARK: - Freeze Management

    @discardableResult
    public func addStreakFreeze(
        id: String,
        expiresAt: Date? = nil
    ) async throws -> StreakFreeze {
        guard let userId = userId else {
            throw StreakError.notLoggedIn
        }

        let freeze = StreakFreeze(
            id: id,
            streakKey: configuration.streakKey,
            earnedDate: Date(),
            usedDate: nil,
            expiresAt: expiresAt
        )

        logger?.trackEvent(event: Event.addStreakFreezeStart(freezeId: freeze.id))

        do {
            try await remote.addStreakFreeze(userId: userId, streakKey: configuration.streakKey, freeze: freeze)
            logger?.trackEvent(event: Event.addStreakFreezeSuccess(freezeId: freeze.id))
            calculateStreak(userId: userId)
        } catch {
            logger?.trackEvent(event: Event.addStreakFreezeFail(error: error))
            throw error
        }

        return freeze
    }

    public func useStreakFreeze(freezeId: String) async throws {
        guard let userId = userId else {
            throw StreakError.notLoggedIn
        }

        logger?.trackEvent(event: Event.useStreakFreezeStart(freezeId: freezeId))

        do {
            try await remote.useStreakFreeze(userId: userId, streakKey: configuration.streakKey, freezeId: freezeId)
            logger?.trackEvent(event: Event.useStreakFreezeSuccess(freezeId: freezeId))
            calculateStreak(userId: userId)
        } catch {
            logger?.trackEvent(event: Event.useStreakFreezeFail(error: error))
            throw error
        }
    }

    @discardableResult
    public func useStreakFreezes() async throws -> UseFreezesResult {
        guard let userId = userId else {
            throw StreakError.notLoggedIn
        }

        // Only applicable when manually consuming freezes
        guard configuration.freezeBehavior == .manuallyConsumeFreezes else {
            return .didNotUseFreezes
        }

        // Check if we can save the streak with freezes
        guard case .canSaveStreakWithFreezes = currentStreakData.applyManualStreakFreezeStatus else {
            return .didNotUseFreezes
        }

        // Get available freezes from current streak data
        guard let availableFreezes = currentStreakData.freezesAvailable, !availableFreezes.isEmpty else {
            return .didNotUseFreezes
        }

        // Get the last event date
        guard let lastEventDate = currentStreakData.lastEventDate else {
            return .didNotUseFreezes
        }

        logger?.trackEvent(event: Event.useStreakFreezesStart)

        do {
            var calendar = Calendar.current
            if let timezone = currentStreakData.lastEventTimezone {
                calendar.timeZone = TimeZone(identifier: timezone) ?? .current
            }

            // Use StreakCalculator helper to determine which days need freezes
            let gapDays = StreakCalculator.calculateGapDays(
                from: lastEventDate,
                to: Date(),
                calendar: calendar
            )

            guard !gapDays.isEmpty else {
                return .didNotUseFreezes
            }

            // Use StreakCalculator helper to select freezes in FIFO order
            let freezeConsumptions = StreakCalculator.selectFreezesForDays(
                daysToFill: gapDays,
                availableFreezes: availableFreezes
            )

            guard !freezeConsumptions.isEmpty else {
                return .didNotUseFreezes
            }

            // Apply each freeze consumption
            for consumption in freezeConsumptions {
                // Create freeze event for this day
                let freezeEvent = StreakEvent(
                    id: UUID().uuidString,
                    timestamp: consumption.date,
                    timezone: currentStreakData.lastEventTimezone ?? TimeZone.current.identifier,
                    isFreeze: true,
                    freezeId: consumption.freezeId
                )
                try await remote.addEvent(userId: userId, streakKey: configuration.streakKey, event: freezeEvent)

                // Mark freeze as used
                try await remote.useStreakFreeze(userId: userId, streakKey: configuration.streakKey, freezeId: consumption.freezeId)

                logger?.trackEvent(event: Event.freezeManuallyConsumed(freezeId: consumption.freezeId, date: consumption.date))
            }

            // Recalculate streak after applying freezes
            calculateStreak(userId: userId)

            logger?.trackEvent(event: Event.useStreakFreezesSuccess(count: freezeConsumptions.count))

            return .didUseFreezesAndSavedStreak
        } catch {
            logger?.trackEvent(event: Event.useStreakFreezesFail(error: error))
            throw error
        }
    }

    public func getAllStreakFreezes() async throws -> [StreakFreeze] {
        guard let userId = userId else {
            throw StreakError.notLoggedIn
        }
        return try await remote.getAllStreakFreezes(userId: userId, streakKey: configuration.streakKey)
    }

    public func recalculateStreak() {
        guard let userId = userId else {
            return
        }
        calculateStreak(userId: userId)
    }

    // MARK: - Private Helpers

    private func calculateStreak(userId: String) {
        if configuration.useServerCalculation {
            // Server-side calculation
            Task {
                do {
                    try await remote.calculateStreak(userId: userId, streakKey: configuration.streakKey)
                } catch {
                    logger?.trackEvent(event: Event.calculateStreakFail(error: error))
                }
            }
        } else {
            // Client-side calculation
            logger?.trackEvent(event: Event.calculateStreakStart)

            Task {
                do {
                    let events = try await remote.getAllEvents(userId: userId, streakKey: configuration.streakKey)
                    let freezes = try await remote.getAllStreakFreezes(userId: userId, streakKey: configuration.streakKey)

                    let (calculatedStreak, freezeConsumptions) = StreakCalculator.calculateStreak(
                        events: events,
                        freezes: freezes,
                        configuration: configuration,
                        userId: userId
                    )

                    // Auto-consume freezes if needed
                    if !freezeConsumptions.isEmpty {
                        for consumption in freezeConsumptions {
                            // Create freeze event
                            let freezeEvent = StreakEvent(
                                id: UUID().uuidString,
                                timestamp: consumption.date,
                                timezone: currentStreakData.lastEventTimezone ?? TimeZone.current.identifier,
                                isFreeze: true,
                                freezeId: consumption.freezeId
                            )
                            try await remote.addEvent(userId: userId, streakKey: configuration.streakKey, event: freezeEvent)

                            // Mark freeze as used
                            try await remote.useStreakFreeze(userId: userId, streakKey: configuration.streakKey, freezeId: consumption.freezeId)

                            logger?.trackEvent(event: Event.freezeAutoConsumed(freezeId: consumption.freezeId, date: consumption.date))
                        }

                        // Recalculate streak after adding freeze events
                        let updatedEvents = try await remote.getAllEvents(userId: userId, streakKey: configuration.streakKey)
                        let updatedFreezes = try await remote.getAllStreakFreezes(userId: userId, streakKey: configuration.streakKey)

                        let (finalStreak, _) = StreakCalculator.calculateStreak(
                            events: updatedEvents,
                            freezes: updatedFreezes,
                            configuration: configuration,
                            userId: userId
                        )

                        currentStreakData = finalStreak
                        try await remote.updateCurrentStreak(userId: userId, streakKey: configuration.streakKey, streak: finalStreak)
                        logger?.trackEvent(event: Event.calculateStreakSuccess(streak: finalStreak))
                    } else {
                        currentStreakData = calculatedStreak
                        try await remote.updateCurrentStreak(userId: userId, streakKey: configuration.streakKey, streak: calculatedStreak)
                        logger?.trackEvent(event: Event.calculateStreakSuccess(streak: calculatedStreak))
                    }
                } catch {
                    logger?.trackEvent(event: Event.calculateStreakFail(error: error))
                }
            }
        }
    }
}

// MARK: - Errors

public enum StreakError: Error {
    case notLoggedIn
}

// MARK: - Analytics Events

extension StreakManager {

    enum Event: GamificationLogEvent {
        case remoteListenerStart
        case remoteListenerSuccess(streak: CurrentStreakData)
        case remoteListenerFail(error: Error)
        case saveLocalStart(streak: CurrentStreakData)
        case saveLocalSuccess(streak: CurrentStreakData)
        case saveLocalFail(error: Error)
        case calculateStreakStart
        case calculateStreakSuccess(streak: CurrentStreakData)
        case calculateStreakFail(error: Error)
        case freezeAutoConsumed(freezeId: String, date: Date)
        case freezeManuallyConsumed(freezeId: String, date: Date)
        case addStreakFreezeStart(freezeId: String)
        case addStreakFreezeSuccess(freezeId: String)
        case addStreakFreezeFail(error: Error)
        case useStreakFreezeStart(freezeId: String)
        case useStreakFreezeSuccess(freezeId: String)
        case useStreakFreezeFail(error: Error)
        case useStreakFreezesStart
        case useStreakFreezesSuccess(count: Int)
        case useStreakFreezesFail(error: Error)

        var eventName: String {
            switch self {
            case .remoteListenerStart:      return "StreakMan_RemoteListener_Start"
            case .remoteListenerSuccess:    return "StreakMan_RemoteListener_Success"
            case .remoteListenerFail:       return "StreakMan_RemoteListener_Fail"
            case .saveLocalStart:           return "StreakMan_SaveLocal_Start"
            case .saveLocalSuccess:         return "StreakMan_SaveLocal_Success"
            case .saveLocalFail:            return "StreakMan_SaveLocal_Fail"
            case .calculateStreakStart:     return "StreakMan_CalculateStreak_Start"
            case .calculateStreakSuccess:   return "StreakMan_CalculateStreak_Success"
            case .calculateStreakFail:      return "StreakMan_CalculateStreak_Fail"
            case .freezeAutoConsumed:       return "StreakMan_Freeze_AutoConsumed"
            case .freezeManuallyConsumed:   return "StreakMan_Freeze_ManuallyConsumed"
            case .addStreakFreezeStart:     return "StreakMan_AddStreakFreeze_Start"
            case .addStreakFreezeSuccess:   return "StreakMan_AddStreakFreeze_Success"
            case .addStreakFreezeFail:      return "StreakMan_AddStreakFreeze_Fail"
            case .useStreakFreezeStart:     return "StreakMan_UseStreakFreeze_Start"
            case .useStreakFreezeSuccess:   return "StreakMan_UseStreakFreeze_Success"
            case .useStreakFreezeFail:      return "StreakMan_UseStreakFreeze_Fail"
            case .useStreakFreezesStart:    return "StreakMan_UseStreakFreezes_Start"
            case .useStreakFreezesSuccess:  return "StreakMan_UseStreakFreezes_Success"
            case .useStreakFreezesFail:     return "StreakMan_UseStreakFreezes_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .remoteListenerSuccess(streak: let streak), .saveLocalStart(streak: let streak), .saveLocalSuccess(streak: let streak), .calculateStreakSuccess(streak: let streak):
                return streak.eventParameters
            case .freezeAutoConsumed(freezeId: let freezeId, date: let date), .freezeManuallyConsumed(freezeId: let freezeId, date: let date):
                return [
                    "freeze_id": freezeId,
                    "frozen_date": date.timeIntervalSince1970
                ]
            case .addStreakFreezeStart(freezeId: let freezeId), .addStreakFreezeSuccess(freezeId: let freezeId), .useStreakFreezeStart(freezeId: let freezeId), .useStreakFreezeSuccess(freezeId: let freezeId):
                return ["freeze_id": freezeId]
            case .useStreakFreezesSuccess(count: let count):
                return ["freezes_used_count": count]
            case .remoteListenerFail(error: let error), .saveLocalFail(error: let error), .calculateStreakFail(error: let error), .addStreakFreezeFail(error: let error), .useStreakFreezeFail(error: let error), .useStreakFreezesFail(error: let error):
                return ["error": error.localizedDescription]
            default:
                return nil
            }
        }

        var type: GamificationLogType {
            switch self {
            case .remoteListenerFail, .saveLocalFail, .calculateStreakFail, .addStreakFreezeFail, .useStreakFreezeFail, .useStreakFreezesFail:
                return .severe
            case .calculateStreakSuccess, .freezeAutoConsumed, .freezeManuallyConsumed, .addStreakFreezeSuccess, .useStreakFreezeSuccess, .useStreakFreezesSuccess:
                return .analytic
            default:
                return .info
            }
        }
    }
}
