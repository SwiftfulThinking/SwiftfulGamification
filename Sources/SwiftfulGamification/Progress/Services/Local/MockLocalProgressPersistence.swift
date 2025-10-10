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
}
