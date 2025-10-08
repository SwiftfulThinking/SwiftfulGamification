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
        addCurrentDataListener(userId: userId)
        calculateExperiencePoints(userId: userId)
    }

    public func logOut() {
        currentDataListenerTask?.cancel()
        currentDataListenerTask = nil
        currentExperiencePointsData = CurrentExperiencePointsData.blank(experienceKey: configuration.experienceKey)
    }

    private func addCurrentDataListener(userId: String) {
        logger?.trackEvent(event: Event.remoteListenerStart)

        currentDataListenerTask?.cancel()
        currentDataListenerTask = Task {
            do {
                for try await value in remote.streamCurrentExperiencePoints(userId: userId, experienceKey: configuration.experienceKey) {
                    self.currentExperiencePointsData = value
                    logger?.trackEvent(event: Event.remoteListenerSuccess(data: value))
                    logger?.addUserProperties(dict: value.eventParameters, isHighPriority: false)
                    self.saveCurrentDataLocally()
                }
            } catch {
                logger?.trackEvent(event: Event.remoteListenerFail(error: error))
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
        userId: String,
        id: String,
        points: Int,
        metadata: [String: GamificationDictionaryValue] = [:]
    ) async throws -> ExperiencePointsEvent {
        let event = ExperiencePointsEvent(
            id: id,
            experienceKey: configuration.experienceKey,
            timestamp: Date(),
            points: points,
            metadata: metadata
        )
        try await remote.addEvent(userId: userId, experienceKey: configuration.experienceKey, event: event)
        calculateExperiencePoints(userId: userId)
        return event
    }

    public func getAllExperiencePointsEvents(userId: String) async throws -> [ExperiencePointsEvent] {
        try await remote.getAllEvents(userId: userId, experienceKey: configuration.experienceKey)
    }

    public func deleteAllExperiencePointsEvents(userId: String) async throws {
        try await remote.deleteAllEvents(userId: userId, experienceKey: configuration.experienceKey)
    }

    public func recalculateExperiencePoints(userId: String) {
        calculateExperiencePoints(userId: userId)
    }

    /// Gets all experience points events matching a specific metadata field value
    /// - Parameters:
    ///   - userId: User ID
    ///   - field: Metadata field key to filter by
    ///   - value: Metadata field value to match
    /// - Returns: Events matching the metadata filter
    public func getAllExperiencePointsEvents(userId: String, forField field: String, equalTo value: GamificationDictionaryValue) async throws -> [ExperiencePointsEvent] {
        let allEvents = try await getAllExperiencePointsEvents(userId: userId)
        return ExperiencePointsCalculator.getEventsForMetadata(events: allEvents, field: field, value: value)
    }

    // MARK: - Private Helpers

    private func calculateExperiencePoints(userId: String) {
        if configuration.useServerCalculation {
            // Server-side calculation
            Task {
                do {
                    try await remote.calculateExperiencePoints(userId: userId, experienceKey: configuration.experienceKey)
                } catch {
                    logger?.trackEvent(event: Event.calculateXPFail(error: error))
                }
            }
        } else {
            // Client-side calculation
            logger?.trackEvent(event: Event.calculateXPStart)

            Task {
                do {
                    let events = try await remote.getAllEvents(userId: userId, experienceKey: configuration.experienceKey)

                    let calculatedData = ExperiencePointsCalculator.calculateExperiencePoints(
                        events: events,
                        configuration: configuration
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
}

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
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .remoteListenerSuccess(data: let data), .saveLocalStart(data: let data), .saveLocalSuccess(data: let data), .calculateXPSuccess(data: let data):
                return data.eventParameters
            case .remoteListenerFail(error: let error), .saveLocalFail(error: let error), .calculateXPFail(error: let error):
                return ["error": error.localizedDescription]
            default:
                return nil
            }
        }

        var type: GamificationLogType {
            switch self {
            case .remoteListenerFail, .saveLocalFail, .calculateXPFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
