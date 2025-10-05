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
        items.forEach { progressItems[$0.id] = $0 }
    }

    public func getAllProgressItems(userId: String) async throws -> [ProgressItem] {
        return Array(progressItems.values)
    }

    public func streamProgressUpdates(userId: String) -> (
        updates: AsyncThrowingStream<ProgressItem, Error>,
        deletions: AsyncThrowingStream<String, Error>
    ) {
        let updates = AsyncThrowingStream<ProgressItem, Error> { continuation in
            let task = Task {
                // Listen for changes (Combine publisher will emit updates)
                for await items in $progressItems.values {
                    for item in items.values {
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

    public func updateProgress(userId: String, item: ProgressItem) async throws {
        progressItems[item.id] = item
    }

    public func deleteProgress(userId: String, id: String) async throws {
        progressItems.removeValue(forKey: id)
    }

    public func deleteAllProgress(userId: String) async throws {
        progressItems.removeAll()
    }
}
