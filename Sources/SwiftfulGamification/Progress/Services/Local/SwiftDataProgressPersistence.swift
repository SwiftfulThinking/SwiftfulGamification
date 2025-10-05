//
//  SwiftDataProgressPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import SwiftData

@MainActor
public final class SwiftDataProgressPersistence: LocalProgressPersistence {

    private let container: ModelContainer
    
    private var mainContext: ModelContext {
        container.mainContext
    }
    
    init() {
        // swiftlint:disable:next force_try
        self.container = try! ModelContainer(for: ProgressItem.self)
    }

    public func getProgressItem(id: String) -> ProgressItem? {
        let descriptor = FetchDescriptor<ProgressItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try? mainContext.fetch(descriptor).first
    }

    public func getAllProgressItems() -> [ProgressItem] {
        let descriptor = FetchDescriptor<ProgressItem>()
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    public func saveProgressItem(_ item: ProgressItem) throws {
        // Check if item already exists
        if let existing = getProgressItem(id: item.id) {
            // Update existing item
            existing.value = item.value
            existing.dateModified = item.dateModified
        } else {
            // Insert new item
            mainContext.insert(item)
        }
        try mainContext.save()
    }

    public func saveProgressItems(_ items: [ProgressItem]) throws {
        // Batch operation: delete existing items and insert new ones
        // This is more efficient for bulk loads than checking each item individually
        for item in items {
            if let existing = getProgressItem(id: item.id) {
                existing.value = item.value
                existing.dateCreated = item.dateCreated
                existing.dateModified = item.dateModified
            } else {
                mainContext.insert(item)
            }
        }
        try mainContext.save()
    }

    public func deleteProgressItem(id: String) throws {
        if let item = getProgressItem(id: id) {
            mainContext.delete(item)
            try mainContext.save()
        }
    }

    public func deleteAllProgressItems() throws {
        let descriptor = FetchDescriptor<ProgressItem>()
        let allItems = (try? mainContext.fetch(descriptor)) ?? []
        for item in allItems {
            mainContext.delete(item)
        }
        try mainContext.save()
    }
}
