import Foundation
import Observation

@MainActor
@Observable
public class StreakManager {
    private let logger: GamificationLogger?
    private let remote: RemoteStreakService
    private let local: LocalStreakPersistence
    internal let configuration: StreakConfiguration

    public private(set) var currentStreakData: CurrentStreakData?
    private var currentStreakListenerTask: Task<Void, Error>?

    public init(
        services: StreakServices,
        configuration: StreakConfiguration,
        logger: GamificationLogger? = nil
    ) {
        self.remote = services.remote
        self.local = services.local
        self.configuration = configuration
        self.logger = logger
        self.currentStreakData = local.getSavedStreakData()
    }

    // MARK: - Public API

    public func logIn(userId: String) async throws {
        addCurrentStreakListener(userId: userId)

        // Calculate streak based on configuration
        if configuration.useServerCalculation {
            try await remote.calculateStreak(userId: userId)
        } else {
            calculateStreak(userId: userId)
        }
    }

    public func logOut() {
        currentStreakListenerTask?.cancel()
        currentStreakListenerTask = nil
        currentStreakData = nil
    }

    private func addCurrentStreakListener(userId: String) {
        logger?.trackEvent(event: Event.remoteListenerStart)

        currentStreakListenerTask?.cancel()
        currentStreakListenerTask = Task {
            do {
                for try await value in remote.streamCurrentStreak(userId: userId) {
                    self.currentStreakData = value
                    logger?.trackEvent(event: Event.remoteListenerSuccess(streak: value))

                    if let streak = value {
                        logger?.addUserProperties(dict: streak.eventParameters, isHighPriority: false)
                    }

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
                try local.saveCurrentStreakData(currentStreakData)
                logger?.trackEvent(event: Event.saveLocalSuccess(streak: currentStreakData))
            } catch {
                logger?.trackEvent(event: Event.saveLocalFail(error: error))
            }
        }
    }

    public func addStreakEvent(userId: String, event: StreakEvent) async throws {
        try await remote.addEvent(userId: userId, event: event)

        // Calculate streak based on configuration
        if configuration.useServerCalculation {
            try await remote.calculateStreak(userId: userId)
        } else {
            calculateStreak(userId: userId)
        }
    }

    public func getAllStreakEvents(userId: String) async throws -> [StreakEvent] {
        try await remote.getAllEvents(userId: userId)
    }

    public func deleteAllStreakEvents(userId: String) async throws {
        try await remote.deleteAllEvents(userId: userId)
    }

    // MARK: - Freeze Management

    public func addStreakFreeze(userId: String, freeze: StreakFreeze) async throws {
        try await remote.addStreakFreeze(userId: userId, freeze: freeze)
    }

    public func useStreakFreeze(userId: String, freezeId: String) async throws {
        try await remote.useStreakFreeze(userId: userId, freezeId: freezeId)
    }

    public func getAllStreakFreezes(userId: String) async throws -> [StreakFreeze] {
        try await remote.getAllStreakFreezes(userId: userId)
    }

    public func recalculateStreak(userId: String) async throws {
        if configuration.useServerCalculation {
            try await remote.calculateStreak(userId: userId)
        } else {
            calculateStreak(userId: userId)
        }
    }

    // MARK: - Private Helpers

    private func calculateStreak(userId: String) {
        logger?.trackEvent(event: Event.calculateStreakStart)

        Task {
            do {
                let events = try await remote.getAllEvents(userId: userId)
                let freezes = try await remote.getAllStreakFreezes(userId: userId)

                let (calculatedStreak, freezeConsumptions) = StreakCalculator.calculateStreak(
                    events: events,
                    freezes: freezes,
                    configuration: configuration
                )

                // Auto-consume freezes if needed
                for consumption in freezeConsumptions {
                    // Create freeze event
                    let freezeEvent = StreakEvent(
                        id: UUID().uuidString,
                        timestamp: consumption.date,
                        timezone: currentStreakData?.lastEventTimezone ?? TimeZone.current.identifier,
                        metadata: [
                            "is_freeze": .bool(true),
                            "freeze_id": .string(consumption.freezeId)
                        ]
                    )
                    try await remote.addEvent(userId: userId, event: freezeEvent)

                    // Mark freeze as used
                    try await remote.useStreakFreeze(userId: userId, freezeId: consumption.freezeId)

                    logger?.trackEvent(event: Event.freezeAutoConsumed(freezeId: consumption.freezeId, date: consumption.date))
                }

                currentStreakData = calculatedStreak
                try await remote.updateCurrentStreak(userId: userId, streak: calculatedStreak)

                logger?.trackEvent(event: Event.calculateStreakSuccess(streak: calculatedStreak))
            } catch {
                logger?.trackEvent(event: Event.calculateStreakFail(error: error))
            }
        }
    }
}

extension StreakManager {

    enum Event: GamificationLogEvent {
        case remoteListenerStart
        case remoteListenerSuccess(streak: CurrentStreakData?)
        case remoteListenerFail(error: Error)
        case saveLocalStart(streak: CurrentStreakData?)
        case saveLocalSuccess(streak: CurrentStreakData?)
        case saveLocalFail(error: Error)
        case calculateStreakStart
        case calculateStreakSuccess(streak: CurrentStreakData)
        case calculateStreakFail(error: Error)
        case freezeAutoConsumed(freezeId: String, date: Date)

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
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .remoteListenerSuccess(streak: let streak), .saveLocalStart(streak: let streak), .saveLocalSuccess(streak: let streak):
                return streak?.eventParameters
            case .calculateStreakSuccess(streak: let streak):
                return streak.eventParameters
            case .freezeAutoConsumed(freezeId: let freezeId, date: let date):
                return [
                    "freeze_id": freezeId,
                    "frozen_date": date.timeIntervalSince1970
                ]
            case .remoteListenerFail(error: let error), .saveLocalFail(error: let error), .calculateStreakFail(error: let error):
                return ["error": error.localizedDescription]
            default:
                return nil
            }
        }

        var type: GamificationLogType {
            switch self {
            case .remoteListenerFail, .saveLocalFail, .calculateStreakFail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
