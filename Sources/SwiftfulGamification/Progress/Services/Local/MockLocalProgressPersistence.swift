//
//  MockLocalProgressPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public final class MockLocalProgressPersistence: LocalProgressPersistence {

    private var items: [String: ProgressItem] = [:]
    private var userIds: [String: String] = [:]
    private var pendingWrites: [String: [ProgressItem]] = [:]

    public init(items: [ProgressItem] = []) {
        items.forEach { self.items[$0.compositeId] = $0 }
    }

    public func getProgressItem(progressKey: String, id: String) -> ProgressItem? {
        let compositeId = "\(progressKey)_\(id)"
        return items[compositeId]
    }

    public func getAllProgressItems(progressKey: String) -> [ProgressItem] {
        return items.values.filter { $0.progressKey == progressKey }
    }

    public func saveProgressItem(_ item: ProgressItem) throws {
        items[item.compositeId] = item
    }

    nonisolated public func saveProgressItems(_ items: [ProgressItem]) async throws {
        await MainActor.run {
            items.forEach { self.items[$0.compositeId] = $0 }
        }
    }

    public func deleteProgressItem(progressKey: String, id: String) throws {
        let compositeId = "\(progressKey)_\(id)"
        items.removeValue(forKey: compositeId)
    }

    nonisolated public func deleteAllProgressItems(progressKey: String) async throws {
        await MainActor.run {
            items = items.filter { $0.value.progressKey != progressKey }
        }
    }

    public func saveUserId(_ userId: String, progressKey: String) {
        if userId.isEmpty {
            userIds.removeValue(forKey: progressKey)
        } else {
            userIds[progressKey] = userId
        }
    }

    public func getUserId(progressKey: String) -> String? {
        let userId = userIds[progressKey]
        return userId?.isEmpty == true ? nil : userId
    }

    public func addPendingWrite(_ item: ProgressItem) throws {
        var writes = pendingWrites[item.progressKey] ?? []
        // Replace if same item already pending and new progress is greater, otherwise append
        if let index = writes.firstIndex(where: { $0.sanitizedId == item.sanitizedId }) {
            if item.value > writes[index].value {
                writes[index] = item
            }
        } else {
            writes.append(item)
        }
        pendingWrites[item.progressKey] = writes
    }

    public func getPendingWrites(progressKey: String) -> [ProgressItem] {
        return pendingWrites[progressKey] ?? []
    }

    public func clearPendingWrites(progressKey: String) throws {
        pendingWrites.removeValue(forKey: progressKey)
    }
}
