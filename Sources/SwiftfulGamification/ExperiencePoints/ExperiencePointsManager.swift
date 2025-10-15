import Foundation
import Observation

@MainActor
@Observable
public class ExperiencePointsManager {
    private let logger: GamificationLogger?
    private let remote: RemoteExperiencePointsService
    private let local: LocalExperiencePointsPersistence
    internal let configuration: ExperiencePointsConfiguration

    public private(set) var currentExperiencePointsData: CurrentExperiencePointsData
    private var currentDataListenerTask: Task<Void, Error>?
    private var listenerFailedToAttach: Bool = false

    private var userId: String? {
        currentExperiencePointsData.userId
    }

    public init(
        services: ExperiencePointsServices,
        configuration: ExperiencePointsConfiguration,
        logger: GamificationLogger? = nil
    ) {
        self.remote = services.remote
        self.local = services.local
        self.configuration = configuration
        self.logger = logger
        self.currentExperiencePointsData = local.getSavedExperiencePointsData(experienceKey: configuration.experienceKey) ?? CurrentExperiencePointsData.blank(experienceKey: configuration.experienceKey)
    }

    // MARK: - Public API

    public func logIn(userId: String) async throws {
        // If userId is changing, log out first to clean up old listeners
        if self.userId != userId {
            logOut()
        }

        if currentExperiencePointsData.userId != userId {
            currentExperiencePointsData = currentExperiencePointsData.updatingUserId(userId)
        }

        addCurrentDataListener(userId: userId)
        calculateExperiencePoints(userId: userId)
    }

    public func logOut() {
        currentDataListenerTask?.cancel()
        currentDataListenerTask = nil
        let blank = CurrentExperiencePointsData.blank(experienceKey: configuration.experienceKey)
        try? local.saveCurrentExperiencePointsData(experienceKey: configuration.experienceKey, blank)
        currentExperiencePointsData = blank
    }

    private func addCurrentDataListener(userId: String) {
        logger?.trackEvent(event: Event.remoteListenerStart)

        // Clear the failure flag when attempting to attach listener
        listenerFailedToAttach = false

        currentDataListenerTask?.cancel()
        currentDataListenerTask = Task {
            do {
                for try await value in remote.streamCurrentExperiencePoints(userId: userId, experienceKey: configuration.experienceKey) {
                    // Preserve userId if incoming data doesn't have it
                    let updatedValue = value.userId == nil ? value.updatingUserId(userId) : value
                    self.currentExperiencePointsData = updatedValue
                    logger?.trackEvent(event: Event.remoteListenerSuccess(data: updatedValue))
                    logger?.addUserProperties(dict: updatedValue.eventParameters, isHighPriority: false)
                    self.saveCurrentDataLocally()
                }
            } catch {
                logger?.trackEvent(event: Event.remoteListenerFail(error: error))
                self.listenerFailedToAttach = true
            }
        }
    }

    private func saveCurrentDataLocally() {
        logger?.trackEvent(event: Event.saveLocalStart(data: currentExperiencePointsData))

        Task {
            do {
                try local.saveCurrentExperiencePointsData(experienceKey: configuration.experienceKey, currentExperiencePointsData)
                logger?.trackEvent(event: Event.saveLocalSuccess(data: currentExperiencePointsData))
            } catch {
                logger?.trackEvent(event: Event.saveLocalFail(error: error))
            }
        }
    }

    @discardableResult
    public func addExperiencePoints(
        points: Int,
        metadata: [String: GamificationDictionaryValue] = [:]
    ) async throws -> ExperiencePointsEvent {
        guard let userId = userId else {
            throw ExperiencePointsError.notLoggedIn
        }

        defer {
            // Retry listener if it previously failed
            if listenerFailedToAttach {
                addCurrentDataListener(userId: userId)
            }
        }

        let event = ExperiencePointsEvent(
            id: UUID().uuidString,
            experienceKey: configuration.experienceKey,
            timestamp: Date(),
            points: points,
            metadata: metadata
        )

        logger?.trackEvent(event: Event.addExperiencePointsStart(event: event))

        do {
            try await remote.addEvent(userId: userId, experienceKey: configuration.experienceKey, event: event)
            logger?.trackEvent(event: Event.addExperiencePointsSuccess(event: event))
            await calculateExperiencePointsAsync(userId: userId)
            return event
        } catch {
            logger?.trackEvent(event: Event.addExperiencePointsFail(error: error))
            throw error
        }
    }

    public func getAllExperiencePointsEvents() async throws -> [ExperiencePointsEvent] {
        guard let userId = userId else {
            throw ExperiencePointsError.notLoggedIn
        }
        return try await remote.getAllEvents(userId: userId, experienceKey: configuration.experienceKey)
    }

    public func deleteAllExperiencePointsEvents() async throws {
        guard let userId = userId else {
            throw ExperiencePointsError.notLoggedIn
        }
        try await remote.deleteAllEvents(userId: userId, experienceKey: configuration.experienceKey)
    }

    public func recalculateExperiencePoints() {
        guard let userId = userId else {
            return
        }
        calculateExperiencePoints(userId: userId)
    }

    /// Gets all experience points events matching a specific metadata field value
    /// - Parameters:
    ///   - field: Metadata field key to filter by
    ///   - value: Metadata field value to match
    /// - Returns: Events matching the metadata filter
    public func getAllExperiencePointsEvents(forField field: String, equalTo value: GamificationDictionaryValue) async throws -> [ExperiencePointsEvent] {
        let allEvents = try await getAllExperiencePointsEvents()
        return ExperiencePointsCalculator.getEventsForMetadata(events: allEvents, field: field, value: value)
    }

    // MARK: - Private Helpers

    private func calculateExperiencePoints(userId: String) {
        Task {
            await calculateExperiencePointsAsync(userId: userId)
        }
    }

    private func calculateExperiencePointsAsync(userId: String) async {
        if configuration.useServerCalculation {
            // Server-side calculation
            do {
                try await remote.calculateExperiencePoints(userId: userId, experienceKey: configuration.experienceKey)
            } catch {
                logger?.trackEvent(event: Event.calculateXPFail(error: error))
            }
        } else {
            // Client-side calculation
            logger?.trackEvent(event: Event.calculateXPStart)

            do {
                let events = try await remote.getAllEvents(userId: userId, experienceKey: configuration.experienceKey)

                let calculatedData = ExperiencePointsCalculator.calculateExperiencePoints(
                    events: events,
                    configuration: configuration,
                    userId: userId
                )

                currentExperiencePointsData = calculatedData
                try await remote.updateCurrentExperiencePoints(userId: userId, experienceKey: configuration.experienceKey, data: calculatedData)

                logger?.trackEvent(event: Event.calculateXPSuccess(data: calculatedData))
            } catch {
                logger?.trackEvent(event: Event.calculateXPFail(error: error))
            }
        }
    }
}

// MARK: - Errors

public enum ExperiencePointsError: Error {
    case notLoggedIn
}

// MARK: - Analytics Events

extension ExperiencePointsManager {

    enum Event: GamificationLogEvent {
        case remoteListenerStart
        case remoteListenerSuccess(data: CurrentExperiencePointsData)
        case remoteListenerFail(error: Error)
        case saveLocalStart(data: CurrentExperiencePointsData)
        case saveLocalSuccess(data: CurrentExperiencePointsData)
        case saveLocalFail(error: Error)
        case calculateXPStart
        case calculateXPSuccess(data: CurrentExperiencePointsData)
        case calculateXPFail(error: Error)
        case addExperiencePointsStart(event: ExperiencePointsEvent)
        case addExperiencePointsSuccess(event: ExperiencePointsEvent)
        case addExperiencePointsFail(error: Error)

        var eventName: String {
            switch self {
            case .remoteListenerStart:      return "XPMan_RemoteListener_Start"
            case .remoteListenerSuccess:    return "XPMan_RemoteListener_Success"
            case .remoteListenerFail:       return "XPMan_RemoteListener_Fail"
            case .saveLocalStart:           return "XPMan_SaveLocal_Start"
            case .saveLocalSuccess:         return "XPMan_SaveLocal_Success"
            case .saveLocalFail:            return "XPMan_SaveLocal_Fail"
            case .calculateXPStart:         return "XPMan_CalculateXP_Start"
            case .calculateXPSuccess:       return "XPMan_CalculateXP_Success"
            case .calculateXPFail:          return "XPMan_CalculateXP_Fail"
            case .addExperiencePointsStart: return "XPMan_AddExperiencePoints_Start"
            case .addExperiencePointsSuccess: return "XPMan_AddExperiencePoints_Success"
            case .addExperiencePointsFail:  return "XPMan_AddExperiencePoints_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .remoteListenerSuccess(data: let data), .saveLocalStart(data: let data), .saveLocalSuccess(data: let data), .calculateXPSuccess(data: let data):
                return data.eventParameters
            case .addExperiencePointsStart(event: let event), .addExperiencePointsSuccess(event: let event):
                return event.eventParameters
            case .remoteListenerFail(error: let error), .saveLocalFail(error: let error), .calculateXPFail(error: let error), .addExperiencePointsFail(error: let error):
                return ["error": error.localizedDescription]
            default:
                return nil
            }
        }

        var type: GamificationLogType {
            switch self {
            case .remoteListenerFail, .saveLocalFail, .calculateXPFail, .addExperiencePointsFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
