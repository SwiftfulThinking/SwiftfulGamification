//
//  MockRemoteProgressService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import Combine

@MainActor
public class MockRemoteProgressService: RemoteProgressService {

    @Published private var progressItems: [String: ProgressItem] = [:]
    private var deletionContinuations: [UUID: AsyncThrowingStream<String, Error>.Continuation] = [:]

    public init(items: [ProgressItem] = []) {
        items.forEach { progressItems[$0.compositeId] = $0 }
    }

    public func getAllProgressItems(userId: String, progressKey: String) async throws -> [ProgressItem] {
        return progressItems.values.filter { $0.progressKey == progressKey }
    }

    public func streamProgressUpdates(userId: String, progressKey: String) -> (
        updates: AsyncThrowingStream<ProgressItem, Error>,
        deletions: AsyncThrowingStream<String, Error>
    ) {
        let updates = AsyncThrowingStream<ProgressItem, Error> { continuation in
            let task = Task {
                // Listen for changes (Combine publisher will emit the entire dictionary)
                // NOTE: Mock emits ALL items on every change (not just the changed item)
                // This differs from production but is acceptable for testing
                for await itemsDict in $progressItems.values {
                    for item in itemsDict.values where item.progressKey == progressKey {
                        continuation.yield(item)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        let streamId = UUID()
        let deletions = AsyncThrowingStream<String, Error> { continuation in
            // Store continuation to emit deletions later
            self.deletionContinuations[streamId] = continuation

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.deletionContinuations.removeValue(forKey: streamId)
                }
            }
        }

        return (updates, deletions)
    }

    public func addProgress(userId: String, progressKey: String, item: ProgressItem) async throws {
        progressItems[item.compositeId] = item
    }

    public func deleteProgress(userId: String, progressKey: String, id: String) async throws {
        let compositeId = "\(progressKey)_\(id)"
        progressItems.removeValue(forKey: compositeId)

        // Emit deletion to all active streams
        for continuation in deletionContinuations.values {
            continuation.yield(id)
        }
    }

    public func deleteAllProgress(userId: String, progressKey: String) async throws {
        let itemsToDelete = progressItems.values.filter { $0.progressKey == progressKey }
        progressItems = progressItems.filter { $0.value.progressKey != progressKey }

        // Emit all deletions to active streams (using sanitized IDs to match cache keys)
        for item in itemsToDelete {
            for continuation in deletionContinuations.values {
                continuation.yield(item.sanitizedId)
            }
        }
    }
}
