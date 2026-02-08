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
    private var remoteListenerTask: Task<Void, Never>?
    private var listenerFailedToAttach: Bool = false

    public init(
        services: ProgressServices,
        configuration: ProgressConfiguration,
        logger: GamificationLogger? = nil
    ) {
        self.remote = services.remote
        self.local = services.local
        self.configuration = configuration
        self.logger = logger

        self.configure()
    }
    
    private func configure() {
        // Load userId from local persistence
        userId = local.getUserId(progressKey: configuration.progressKey)

        // Load cached data asynchronously to avoid blocking initialization
        // This enables offline access while preventing startup delays
        Task { @MainActor in
            let localItems = local.getAllProgressItems(progressKey: configuration.progressKey)
            for item in localItems {
                progressCache[item.sanitizedId] = item
            }
        }
    }

    // MARK: - Lifecycle

    public func logIn(userId: String) async throws {
        // If userId is changing, log out first to clean up old listeners
        if self.userId != userId {
            await logOut()
        }

        if self.userId != userId {
            self.userId = userId
            local.saveUserId(userId, progressKey: configuration.progressKey)
        }

        // Hybrid sync: Bulk load all items, then stream updates
        await bulkLoadProgress(userId: userId)
        addRemoteListener(userId: userId)
    }

    public func logOut() async {
        remoteListenerTask?.cancel()
        remoteListenerTask = nil
        userId = nil
        try? await local.deleteAllProgressItems(progressKey: configuration.progressKey)
        local.saveUserId("", progressKey: configuration.progressKey) // Clear by saving empty string
        progressCache.removeAll()
    }

    // MARK: - Public API

    /// Get progress value synchronously from in-memory cache
    /// - Parameter id: Progress item ID (will be sanitized for lookup)
    /// - Returns: Progress value (0.0 to 1.0), or 0.0 if not found
    public func getProgress(id: String) -> Double {
        let sanitizedId = id.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        if progressCache.isEmpty {
            return local.getProgressItem(progressKey: configuration.progressKey, id: sanitizedId)?.value ?? 0.0
        }
        return progressCache[sanitizedId]?.value ?? 0.0
    }

    /// Get full progress item synchronously from in-memory cache
    /// - Parameter id: Progress item ID (will be sanitized for lookup)
    /// - Returns: Progress item, or nil if not found
    public func getProgressItem(id: String) -> ProgressItem? {
        let sanitizedId = id.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()
        if progressCache.isEmpty {
            return local.getProgressItem(progressKey: configuration.progressKey, id: sanitizedId)
        }
        return progressCache[sanitizedId]
    }

    /// Get all progress values synchronously from in-memory cache
    /// - Returns: Dictionary of all progress values [id: value] (using original IDs, not sanitized)
    public func getAllProgress() -> [String: Double] {
        if progressCache.isEmpty {
            let items = local.getAllProgressItems(progressKey: configuration.progressKey)
            return Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.value) })
        }
        return Dictionary(uniqueKeysWithValues: progressCache.values.map { ($0.id, $0.value) })
    }

    /// Get all progress items synchronously from in-memory cache
    /// - Returns: Array of all progress items
    public func getAllProgressItems() -> [ProgressItem] {
        if progressCache.isEmpty {
            return local.getAllProgressItems(progressKey: configuration.progressKey)
        }
        return Array(progressCache.values)
    }

    /// Get progress items filtered by metadata field value
    /// - Parameters:
    ///   - metadataField: Metadata field key to filter by
    ///   - value: Metadata field value to match
    /// - Returns: Array of progress items matching the metadata filter
    public func getProgressItems(forMetadataField metadataField: String, equalTo value: GamificationDictionaryValue) -> [ProgressItem] {
        if progressCache.isEmpty {
            let items = local.getAllProgressItems(progressKey: configuration.progressKey)
            return items.filter { $0.metadata[metadataField] == value }
        }
        return progressCache.values.filter { $0.metadata[metadataField] == value }
    }

    /// Get maximum progress value for items filtered by metadata field value
    /// - Parameters:
    ///   - metadataField: Metadata field key to filter by
    ///   - value: Metadata field value to match
    /// - Returns: Maximum progress value (0.0 to 1.0), or 0.0 if no items match
    public func getMaxProgress(forMetadataField metadataField: String, equalTo value: GamificationDictionaryValue) -> Double {
        if progressCache.isEmpty {
            let items = local.getAllProgressItems(progressKey: configuration.progressKey)
            let filtered = items.filter { $0.metadata[metadataField] == value }
            return filtered.map { $0.value }.max() ?? 0.0
        }
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

        defer {
            // Retry listener if it previously failed
            if listenerFailedToAttach {
                addRemoteListener(userId: userId)
            }
        }

        guard value >= 0.0 && value <= 1.0 else {
            logger?.trackEvent(event: Event.addProgressFail(error: ProgressError.invalidValue))
            throw ProgressError.invalidValue
        }

        logger?.trackEvent(event: Event.addProgressStart(id: id, value: value))

        // Sanitize the ID for storage
        let sanitizedId = id.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()

        // Check if new value is higher than existing local value (progress never decreases)
        let existingLocal = local.getProgressItem(progressKey: configuration.progressKey, id: sanitizedId)
        if let existingValue = existingLocal?.value, value < existingValue {
            logger?.trackEvent(event: Event.addProgressSuccess(id: id, value: value))
            return existingLocal! // Ignore updates that would decrease progress, return existing item
        }

        // Create updated item, merging metadata (new values overwrite old ones)
        let existingItem = progressCache[sanitizedId] ?? existingLocal
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

        // Optimistic update: Update cache immediately (using sanitized ID as key)
        progressCache[sanitizedId] = item

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
            // Save to pending writes for later retry
            do {
                try local.addPendingWrite(item)
                logger?.trackEvent(event: Event.addProgressPendingRetry(id: id, value: value))
            } catch {
                logger?.trackEvent(event: Event.saveLocalFail(error: error))
            }
            logger?.trackEvent(event: Event.addProgressFail(error: error))
            throw error
        }

        return item
    }

    /// Delete a single progress item
    /// - Parameter id: Progress item ID (will be sanitized for lookup)
    public func deleteProgress(id: String) async throws {
        guard let userId = userId else {
            logger?.trackEvent(event: Event.deleteProgressFail(error: ProgressError.notLoggedIn))
            throw ProgressError.notLoggedIn
        }

        logger?.trackEvent(event: Event.deleteProgressStart(id: id))

        // Sanitize the ID for storage lookup
        let sanitizedId = id.sanitizeForDatabaseKeysByConvertingToLowercaseAndRemovingWhitespaceAndSpecialCharacters()

        // Delete from remote first
        do {
            try await remote.deleteProgress(userId: userId, progressKey: configuration.progressKey, id: sanitizedId)
            logger?.trackEvent(event: Event.deleteProgressSuccess(id: id))
        } catch {
            logger?.trackEvent(event: Event.deleteProgressFail(error: error))
            throw error
        }

        // Only delete locally if remote succeeds
        progressCache.removeValue(forKey: sanitizedId)

        do {
            try local.deleteProgressItem(progressKey: configuration.progressKey, id: sanitizedId)
            logger?.trackEvent(event: Event.saveLocalSuccess(id: id))
        } catch {
            logger?.trackEvent(event: Event.saveLocalFail(error: error))
        }
    }

    /// Delete all progress items
    public func deleteAllProgress() async throws {
        guard let userId = userId else {
            logger?.trackEvent(event: Event.deleteAllProgressFail(error: ProgressError.notLoggedIn))
            throw ProgressError.notLoggedIn
        }

        logger?.trackEvent(event: Event.deleteAllProgressStart)

        // Delete all from remote first
        do {
            try await remote.deleteAllProgress(userId: userId, progressKey: configuration.progressKey)
            logger?.trackEvent(event: Event.deleteAllProgressSuccess)
        } catch {
            logger?.trackEvent(event: Event.deleteAllProgressFail(error: error))
            throw error
        }

        // Only delete locally if remote succeeds
        progressCache.removeAll()

        do {
            try await local.deleteAllProgressItems(progressKey: configuration.progressKey)
            logger?.trackEvent(event: Event.saveLocalSuccess(id: "all"))
        } catch {
            logger?.trackEvent(event: Event.saveLocalFail(error: error))
        }
    }

    // MARK: - Private Helpers

    private func bulkLoadProgress(userId: String) async {
        logger?.trackEvent(event: Event.bulkLoadStart)

        do {
            let items = try await remote.getAllProgressItems(userId: userId, progressKey: configuration.progressKey)

            // Update cache (using sanitized ID as key)
            for item in items {
                progressCache[item.sanitizedId] = item
            }

            // Save all to local storage (runs on background thread)
            try await local.saveProgressItems(items)

            logger?.trackEvent(event: Event.bulkLoadSuccess(count: items.count))
        } catch {
            logger?.trackEvent(event: Event.bulkLoadFail(error: error))
        }
    }

    private func uploadPendingWritesIfNeeded(userId: String) async {
        let pendingWrites = local.getPendingWrites(progressKey: configuration.progressKey)

        guard !pendingWrites.isEmpty else { return }

        logger?.trackEvent(event: Event.uploadPendingWritesStart(count: pendingWrites.count))

        var successCount = 0
        var failedItems: [ProgressItem] = []

        for item in pendingWrites {
            do {
                try await remote.addProgress(userId: userId, progressKey: configuration.progressKey, item: item)
                successCount += 1
            } catch {
                failedItems.append(item)
                logger?.trackEvent(event: Event.uploadPendingWriteItemFail(id: item.id, error: error))
            }
        }

        // Clear all pending writes, then re-save any that failed
        if successCount > 0 {
            do {
                try local.clearPendingWrites(progressKey: configuration.progressKey)

                // Re-save failed items so they retry next time
                for item in failedItems {
                    try local.addPendingWrite(item)
                }

                logger?.trackEvent(event: Event.uploadPendingWritesSuccess(successCount: successCount, failCount: failedItems.count))
            } catch {
                logger?.trackEvent(event: Event.saveLocalFail(error: error))
            }
        } else {
            logger?.trackEvent(event: Event.uploadPendingWritesFail(count: pendingWrites.count))
        }
    }

    private func addRemoteListener(userId: String) {
        logger?.trackEvent(event: Event.remoteListenerStart)

        // Clear the failure flag when attempting to attach listener
        listenerFailedToAttach = false

        remoteListenerTask?.cancel()

        let (updates, deletions) = remote.streamProgressUpdates(userId: userId, progressKey: configuration.progressKey)

        remoteListenerTask = Task { @MainActor in
            await uploadPendingWritesIfNeeded(userId: userId)

            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    await self.handleProgressUpdates(updates)
                }
                group.addTask { @MainActor in
                    await self.handleProgressDeletions(deletions)
                }
            }
        }
    }

    private func handleProgressUpdates(_ updates: AsyncThrowingStream<ProgressItem, Error>) async {
        do {
            for try await item in updates {
                // Check if local value is higher than remote (progress should never decrease)
                if let currentItem = progressCache[item.sanitizedId], currentItem.value > item.value {
                    // Local is ahead - update remote with local value
                    let correctedItem = ProgressItem(
                        id: item.id,
                        progressKey: configuration.progressKey,
                        value: currentItem.value,
                        dateCreated: item.dateCreated,
                        dateModified: Date(),
                        metadata: currentItem.metadata
                    )

                    if let userId = self.userId {
                        do {
                            try await remote.addProgress(userId: userId, progressKey: configuration.progressKey, item: correctedItem)
                            logger?.trackEvent(event: Event.remoteListenerSuccess(id: item.id))
                        } catch {
                            logger?.trackEvent(event: Event.saveLocalFail(error: error))
                        }
                    }
                } else {
                    // Remote is equal or ahead - update local (using sanitized ID as cache key)
                    progressCache[item.sanitizedId] = item

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
            self.listenerFailedToAttach = true
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
            self.listenerFailedToAttach = true
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
        case addProgressPendingRetry(id: String, value: Double)
        case addProgressFail(error: Error)
        case deleteProgressStart(id: String)
        case deleteProgressSuccess(id: String)
        case deleteProgressFail(error: Error)
        case deleteAllProgressStart
        case deleteAllProgressSuccess
        case deleteAllProgressFail(error: Error)
        case uploadPendingWritesStart(count: Int)
        case uploadPendingWritesSuccess(successCount: Int, failCount: Int)
        case uploadPendingWritesFail(count: Int)
        case uploadPendingWriteItemFail(id: String, error: Error)

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
            case .addProgressPendingRetry:  return "ProgressMan_AddProgress_PendingRetry"
            case .addProgressFail:          return "ProgressMan_AddProgress_Fail"
            case .deleteProgressStart:      return "ProgressMan_DeleteProgress_Start"
            case .deleteProgressSuccess:    return "ProgressMan_DeleteProgress_Success"
            case .deleteProgressFail:       return "ProgressMan_DeleteProgress_Fail"
            case .deleteAllProgressStart:   return "ProgressMan_DeleteAllProgress_Start"
            case .deleteAllProgressSuccess: return "ProgressMan_DeleteAllProgress_Success"
            case .deleteAllProgressFail:    return "ProgressMan_DeleteAllProgress_Fail"
            case .uploadPendingWritesStart: return "ProgressMan_UploadPendingWrites_Start"
            case .uploadPendingWritesSuccess: return "ProgressMan_UploadPendingWrites_Success"
            case .uploadPendingWritesFail:  return "ProgressMan_UploadPendingWrites_Fail"
            case .uploadPendingWriteItemFail: return "ProgressMan_UploadPendingWriteItem_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .bulkLoadSuccess(count: let count):
                return ["progress_count": count]
            case .remoteListenerSuccess(id: let id), .saveLocalSuccess(id: let id), .deleteProgressStart(id: let id), .deleteProgressSuccess(id: let id):
                return ["progress_id": id]
            case .addProgressStart(id: let id, value: let value), .addProgressSuccess(id: let id, value: let value), .addProgressPendingRetry(id: let id, value: let value):
                return ["progress_id": id, "progress_value": value]
            case .uploadPendingWritesStart(count: let count):
                return ["pending_writes_count": count]
            case .uploadPendingWritesSuccess(successCount: let successCount, failCount: let failCount):
                return ["success_count": successCount, "fail_count": failCount]
            case .uploadPendingWritesFail(count: let count):
                return ["pending_writes_count": count]
            case .uploadPendingWriteItemFail(id: let id, error: let error):
                return ["progress_id": id, "error": error.localizedDescription]
            case .bulkLoadFail(error: let error), .remoteListenerFail(error: let error), .saveLocalFail(error: let error), .addProgressFail(error: let error), .deleteProgressFail(error: let error), .deleteAllProgressFail(error: let error):
                return ["error": error.localizedDescription]
            default:
                return nil
            }
        }

        var type: GamificationLogType {
            switch self {
            case .bulkLoadFail, .remoteListenerFail, .saveLocalFail, .addProgressFail, .deleteProgressFail, .deleteAllProgressFail, .uploadPendingWritesFail, .uploadPendingWriteItemFail:
                return .severe
            case .uploadPendingWritesSuccess:
                return .analytic
            default:
                return .info
            }
        }
    }
}
