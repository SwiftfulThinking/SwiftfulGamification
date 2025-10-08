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
                // Listen for changes (Combine publisher will emit updates)
                for await items in $progressItems.values {
                    for item in items.values where item.progressKey == progressKey {
                        continuation.yield(item)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }

        let deletions = AsyncThrowingStream<String, Error> { continuation in
            // Mock doesn't track deletions separately
            continuation.onTermination = { @Sendable _ in }
        }

        return (updates, deletions)
    }

    public func updateProgress(userId: String, progressKey: String, item: ProgressItem) async throws {
        progressItems[item.compositeId] = item
    }

    public func deleteProgress(userId: String, progressKey: String, id: String) async throws {
        let compositeId = "\(progressKey)_\(id)"
        progressItems.removeValue(forKey: compositeId)
    }

    public func deleteAllProgress(userId: String, progressKey: String) async throws {
        progressItems = progressItems.filter { $0.value.progressKey != progressKey }
    }
}
