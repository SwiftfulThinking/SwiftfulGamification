import Foundation
import Observation

@MainActor
@Observable
public class ProgressManager {
    private let logger: GamificationLogger?
    private let remote: RemoteProgressService
    private let local: LocalProgressPersistence
    internal let configuration: ProgressConfiguration

    // In-memory cache for synchronous reads
    private var progressCache: [String: ProgressItem] = [:]

    private var userId: String?
    private var remoteListenerTask: Task<Void, Error>?

    public init(
        services: ProgressServices,
        configuration: ProgressConfiguration,
        logger: GamificationLogger? = nil
    ) {
        self.remote = services.remote
        self.local = services.local
        self.configuration = configuration
        self.logger = logger

        // Load cached data asynchronously to avoid blocking initialization
        // This enables offline access while preventing startup delays
        Task { @MainActor in
            let localItems = local.getAllProgressItems(progressKey: configuration.progressKey)
            for item in localItems {
                progressCache[item.id] = item
            }
        }
    }

    // MARK: - Lifecycle

    public func logIn(userId: String) async throws {
        self.userId = userId

        // Hybrid sync: Bulk load all items, then stream updates
        await bulkLoadProgress(userId: userId)
        addRemoteListener(userId: userId)
    }

    public func logOut() {
        remoteListenerTask?.cancel()
        remoteListenerTask = nil
        userId = nil
        progressCache.removeAll()
    }

    // MARK: - Public API

    /// Get progress value synchronously from in-memory cache
    /// - Parameter id: Progress item ID
    /// - Returns: Progress value (0.0 to 1.0), or 0.0 if not found
    public func getProgress(id: String) -> Double {
        return progressCache[id]?.value ?? 0.0
    }

    /// Get full progress item synchronously from in-memory cache
    /// - Parameter id: Progress item ID
    /// - Returns: Progress item, or nil if not found
    public func getProgressItem(id: String) -> ProgressItem? {
        return progressCache[id]
    }

    /// Get all progress values synchronously from in-memory cache
    /// - Returns: Dictionary of all progress values [id: value]
    public func getAllProgress() -> [String: Double] {
        return progressCache.mapValues { $0.value }
    }

    /// Get all progress items synchronously from in-memory cache
    /// - Returns: Array of all progress items
    public func getAllProgressItems() -> [ProgressItem] {
        return Array(progressCache.values)
    }

    /// Get progress items filtered by metadata field value
    /// - Parameters:
    ///   - metadataField: Metadata field key to filter by
    ///   - value: Metadata field value to match
    /// - Returns: Array of progress items matching the metadata filter
    public func getProgressItems(forMetadataField metadataField: String, equalTo value: GamificationDictionaryValue) -> [ProgressItem] {
        return progressCache.values.filter { $0.metadata[metadataField] == value }
    }

    /// Get maximum progress value for items filtered by metadata field value
    /// - Parameters:
    ///   - metadataField: Metadata field key to filter by
    ///   - value: Metadata field value to match
    /// - Returns: Maximum progress value (0.0 to 1.0), or 0.0 if no items match
    public func getMaxProgress(forMetadataField metadataField: String, equalTo value: GamificationDictionaryValue) -> Double {
        let filtered = progressCache.values.filter { $0.metadata[metadataField] == value }
        return filtered.map { $0.value }.max() ?? 0.0
    }

    /// Add or update progress value with optimistic update
    /// - Parameters:
    ///   - id: Progress item ID
    ///   - value: Progress value (0.0 to 1.0)
    ///   - metadata: Optional metadata to merge with existing metadata (new values overwrite old ones)
    /// - Returns: The created or updated ProgressItem
    @discardableResult
    public func addProgress(id: String, value: Double, metadata: [String: GamificationDictionaryValue]? = nil) async throws -> ProgressItem {
        guard let userId = userId else {
            logger?.trackEvent(event: Event.addProgressFail(error: ProgressError.notLoggedIn))
            throw ProgressError.notLoggedIn
        }

        guard value >= 0.0 && value <= 1.0 else {
            logger?.trackEvent(event: Event.addProgressFail(error: ProgressError.invalidValue))
            throw ProgressError.invalidValue
        }

        logger?.trackEvent(event: Event.addProgressStart(id: id, value: value))

        // Check if new value is higher than existing local value (progress never decreases)
        let existingLocal = local.getProgressItem(progressKey: configuration.progressKey, id: id)
        if let existingValue = existingLocal?.value, value < existingValue {
            logger?.trackEvent(event: Event.addProgressSuccess(id: id, value: value))
            return existingLocal! // Ignore updates that would decrease progress, return existing item
        }

        // Create updated item, merging metadata (new values overwrite old ones)
        let existingItem = progressCache[id] ?? existingLocal
        var mergedMetadata = existingItem?.metadata ?? [:]
        if let metadata = metadata {
            mergedMetadata.merge(metadata) { _, new in new }
        }

        let item = ProgressItem(
            id: id,
            progressKey: configuration.progressKey,
            value: value,
            dateCreated: existingItem?.dateCreated ?? Date(),
            dateModified: Date(),
            metadata: mergedMetadata
        )

        // Optimistic update: Update cache immediately
        progressCache[id] = item

        // Save locally
        do {
            try local.saveProgressItem(item)
            logger?.trackEvent(event: Event.saveLocalSuccess(id: id))
        } catch {
            logger?.trackEvent(event: Event.saveLocalFail(error: error))
        }

        // Save to remote
        do {
            try await remote.addProgress(userId: userId, progressKey: configuration.progressKey, item: item)
            logger?.trackEvent(event: Event.addProgressSuccess(id: id, value: value))
        } catch {
            logger?.trackEvent(event: Event.addProgressFail(error: error))
            throw error
        }

        return item
    }

    /// Delete a single progress item
    /// - Parameter id: Progress item ID
    public func deleteProgress(id: String) async throws {
        guard let userId = userId else {
            logger?.trackEvent(event: Event.deleteProgressFail(error: ProgressError.notLoggedIn))
            throw ProgressError.notLoggedIn
        }

        logger?.trackEvent(event: Event.deleteProgressStart(id: id))

        // Remove from cache
        progressCache.removeValue(forKey: id)

        // Delete locally
        do {
            try local.deleteProgressItem(progressKey: configuration.progressKey, id: id)
            logger?.trackEvent(event: Event.saveLocalSuccess(id: id))
        } catch {
            logger?.trackEvent(event: Event.saveLocalFail(error: error))
        }

        // Delete from remote
        do {
            try await remote.deleteProgress(userId: userId, progressKey: configuration.progressKey, id: id)
            logger?.trackEvent(event: Event.deleteProgressSuccess(id: id))
        } catch {
            logger?.trackEvent(event: Event.deleteProgressFail(error: error))
            throw error
        }
    }

    /// Delete all progress items
    public func deleteAllProgress() async throws {
        guard let userId = userId else {
            logger?.trackEvent(event: Event.deleteAllProgressFail(error: ProgressError.notLoggedIn))
            throw ProgressError.notLoggedIn
        }

        logger?.trackEvent(event: Event.deleteAllProgressStart)

        // Clear cache
        progressCache.removeAll()

        // Delete all locally
        do {
            try local.deleteAllProgressItems(progressKey: configuration.progressKey)
            logger?.trackEvent(event: Event.saveLocalSuccess(id: "all"))
        } catch {
            logger?.trackEvent(event: Event.saveLocalFail(error: error))
        }

        // Delete all from remote
        do {
            try await remote.deleteAllProgress(userId: userId, progressKey: configuration.progressKey)
            logger?.trackEvent(event: Event.deleteAllProgressSuccess)
        } catch {
            logger?.trackEvent(event: Event.deleteAllProgressFail(error: error))
            throw error
        }
    }

    // MARK: - Private Helpers

    private func bulkLoadProgress(userId: String) async {
        logger?.trackEvent(event: Event.bulkLoadStart)

        do {
            let items = try await remote.getAllProgressItems(userId: userId, progressKey: configuration.progressKey)

            // Update cache
            for item in items {
                progressCache[item.id] = item
            }

            // Save all to local storage
            try local.saveProgressItems(items)

            logger?.trackEvent(event: Event.bulkLoadSuccess(count: items.count))
        } catch {
            logger?.trackEvent(event: Event.bulkLoadFail(error: error))
        }
    }

    private func addRemoteListener(userId: String) {
        logger?.trackEvent(event: Event.remoteListenerStart)

        remoteListenerTask?.cancel()

        let (updates, deletions) = remote.streamProgressUpdates(userId: userId, progressKey: configuration.progressKey)

        Task { @MainActor in
            await handleProgressUpdates(updates)
        }

        Task { @MainActor in
            await handleProgressDeletions(deletions)
        }
    }

    private func handleProgressUpdates(_ updates: AsyncThrowingStream<ProgressItem, Error>) async {
        do {
            for try await item in updates {
                // Check if local value is higher than remote (progress should never decrease)
                if let currentItem = progressCache[item.id], currentItem.value > item.value {
                    // Local is ahead - update remote with local value
                    let correctedItem = ProgressItem(
                        id: item.id,
                        progressKey: configuration.progressKey,
                        value: currentItem.value,
                        dateCreated: item.dateCreated,
                        dateModified: Date(),
                        metadata: currentItem.metadata
                    )

                    do {
                        try await remote.addProgress(userId: userId ?? "", progressKey: configuration.progressKey, item: correctedItem)
                        logger?.trackEvent(event: Event.remoteListenerSuccess(id: item.id))
                    } catch {
                        logger?.trackEvent(event: Event.saveLocalFail(error: error))
                    }
                } else {
                    // Remote is equal or ahead - update local
                    progressCache[item.id] = item

                    do {
                        try local.saveProgressItem(item)
                        logger?.trackEvent(event: Event.remoteListenerSuccess(id: item.id))
                    } catch {
                        logger?.trackEvent(event: Event.saveLocalFail(error: error))
                    }
                }
            }
        } catch {
            logger?.trackEvent(event: Event.remoteListenerFail(error: error))
        }
    }

    private func handleProgressDeletions(_ deletions: AsyncThrowingStream<String, Error>) async {
        do {
            for try await id in deletions {
                // Remove from cache
                progressCache.removeValue(forKey: id)

                // Delete locally
                do {
                    try local.deleteProgressItem(progressKey: configuration.progressKey, id: id)
                    logger?.trackEvent(event: Event.remoteListenerSuccess(id: id))
                } catch {
                    logger?.trackEvent(event: Event.saveLocalFail(error: error))
                }
            }
        } catch {
            logger?.trackEvent(event: Event.remoteListenerFail(error: error))
        }
    }
}

// MARK: - Errors

public enum ProgressError: Error {
    case notLoggedIn
    case invalidValue
}

// MARK: - Analytics Events

extension ProgressManager {

    enum Event: GamificationLogEvent {
        case bulkLoadStart
        case bulkLoadSuccess(count: Int)
        case bulkLoadFail(error: Error)
        case remoteListenerStart
        case remoteListenerSuccess(id: String)
        case remoteListenerFail(error: Error)
        case saveLocalSuccess(id: String)
        case saveLocalFail(error: Error)
        case addProgressStart(id: String, value: Double)
        case addProgressSuccess(id: String, value: Double)
        case addProgressFail(error: Error)
        case deleteProgressStart(id: String)
        case deleteProgressSuccess(id: String)
        case deleteProgressFail(error: Error)
        case deleteAllProgressStart
        case deleteAllProgressSuccess
        case deleteAllProgressFail(error: Error)

        var eventName: String {
            switch self {
            case .bulkLoadStart:            return "ProgressMan_BulkLoad_Start"
            case .bulkLoadSuccess:          return "ProgressMan_BulkLoad_Success"
            case .bulkLoadFail:             return "ProgressMan_BulkLoad_Fail"
            case .remoteListenerStart:      return "ProgressMan_RemoteListener_Start"
            case .remoteListenerSuccess:    return "ProgressMan_RemoteListener_Success"
            case .remoteListenerFail:       return "ProgressMan_RemoteListener_Fail"
            case .saveLocalSuccess:         return "ProgressMan_SaveLocal_Success"
            case .saveLocalFail:            return "ProgressMan_SaveLocal_Fail"
            case .addProgressStart:         return "ProgressMan_AddProgress_Start"
            case .addProgressSuccess:       return "ProgressMan_AddProgress_Success"
            case .addProgressFail:          return "ProgressMan_AddProgress_Fail"
            case .deleteProgressStart:      return "ProgressMan_DeleteProgress_Start"
            case .deleteProgressSuccess:    return "ProgressMan_DeleteProgress_Success"
            case .deleteProgressFail:       return "ProgressMan_DeleteProgress_Fail"
            case .deleteAllProgressStart:   return "ProgressMan_DeleteAllProgress_Start"
            case .deleteAllProgressSuccess: return "ProgressMan_DeleteAllProgress_Success"
            case .deleteAllProgressFail:    return "ProgressMan_DeleteAllProgress_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .bulkLoadSuccess(count: let count):
                return ["progress_count": count]
            case .remoteListenerSuccess(id: let id), .saveLocalSuccess(id: let id), .deleteProgressStart(id: let id), .deleteProgressSuccess(id: let id):
                return ["progress_id": id]
            case .addProgressStart(id: let id, value: let value), .addProgressSuccess(id: let id, value: let value):
                return ["progress_id": id, "progress_value": value]
            case .bulkLoadFail(error: let error), .remoteListenerFail(error: let error), .saveLocalFail(error: let error), .addProgressFail(error: let error), .deleteProgressFail(error: let error), .deleteAllProgressFail(error: let error):
                return ["error": error.localizedDescription]
            default:
                return nil
            }
        }

        var type: GamificationLogType {
            switch self {
            case .bulkLoadFail, .remoteListenerFail, .saveLocalFail, .addProgressFail, .deleteProgressFail, .deleteAllProgressFail:
                return .severe
            default:
                return .info
            }
        }
    }
}
