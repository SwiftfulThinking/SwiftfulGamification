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
        items.forEach { self.items[$0.id] = $0 }
    }

    public func getProgressItem(id: String) -> ProgressItem? {
        return items[id]
    }

    public func getAllProgressItems() -> [ProgressItem] {
        return Array(items.values)
    }

    public func saveProgressItem(_ item: ProgressItem) throws {
        items[item.id] = item
    }

    public func saveProgressItems(_ items: [ProgressItem]) throws {
        items.forEach { self.items[$0.id] = $0 }
    }

    public func deleteProgressItem(id: String) throws {
        items.removeValue(forKey: id)
    }

    public func deleteAllProgressItems() throws {
        items.removeAll()
    }
}
