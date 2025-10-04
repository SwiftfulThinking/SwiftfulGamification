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

        // Calculate streak if using client-side calculation
        if !configuration.useServerCalculation {
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
                        logger?.addUserProperties(dict: streak.eventParameters, isHighPriority: true)
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

        // Calculate streak if using client-side calculation
        if !configuration.useServerCalculation {
            calculateStreak(userId: userId)
        }
    }

    public func getAllStreakEvents(userId: String) async throws -> [StreakEvent] {
        try await remote.getAllEvents(userId: userId)
    }

    public func deleteAllStreakEvents(userId: String) async throws {
        try await remote.deleteAllEvents(userId: userId)
    }

    private func calculateStreak(userId: String) {
        guard !configuration.useServerCalculation else {
            logger?.trackEvent(event: Event.calculateStreakSkipped)
            return
        }

        logger?.trackEvent(event: Event.calculateStreakStart)

        Task {
            do {
                let events = try await remote.getAllEvents(userId: userId)

                let calculatedStreak = StreakCalculator.calculateStreak(
                    events: events,
                    configuration: configuration
                )

                currentStreakData = calculatedStreak
                saveCurrentStreakLocally()

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
        case calculateStreakSkipped
        case calculateStreakStart
        case calculateStreakSuccess(streak: CurrentStreakData)
        case calculateStreakFail(error: Error)

        var eventName: String {
            switch self {
            case .remoteListenerStart:      return "StreakMan_RemoteListener_Start"
            case .remoteListenerSuccess:    return "StreakMan_RemoteListener_Success"
            case .remoteListenerFail:       return "StreakMan_RemoteListener_Fail"
            case .saveLocalStart:           return "StreakMan_SaveLocal_Start"
            case .saveLocalSuccess:         return "StreakMan_SaveLocal_Success"
            case .saveLocalFail:            return "StreakMan_SaveLocal_Fail"
            case .calculateStreakSkipped:   return "StreakMan_CalculateStreak_Skipped"
            case .calculateStreakStart:     return "StreakMan_CalculateStreak_Start"
            case .calculateStreakSuccess:   return "StreakMan_CalculateStreak_Success"
            case .calculateStreakFail:      return "StreakMan_CalculateStreak_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .remoteListenerSuccess(streak: let streak), .saveLocalStart(streak: let streak), .saveLocalSuccess(streak: let streak):
                return streak?.eventParameters
            case .calculateStreakSuccess(streak: let streak):
                return streak.eventParameters
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
