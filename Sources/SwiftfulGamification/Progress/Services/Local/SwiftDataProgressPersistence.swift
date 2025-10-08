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

    public func getProgressItem(progressKey: String, id: String) -> ProgressItem? {
        let compositeId = "\(progressKey)_\(id)"
        let descriptor = FetchDescriptor<ProgressItem>(
            predicate: #Predicate { $0.compositeId == compositeId }
        )
        return try? mainContext.fetch(descriptor).first
    }

    public func getAllProgressItems(progressKey: String) -> [ProgressItem] {
        let descriptor = FetchDescriptor<ProgressItem>(
            predicate: #Predicate { $0.progressKey == progressKey }
        )
        return (try? mainContext.fetch(descriptor)) ?? []
    }

    public func saveProgressItem(_ item: ProgressItem) throws {
        // Check if item already exists using compositeId
        let descriptor = FetchDescriptor<ProgressItem>(
            predicate: #Predicate { $0.compositeId == item.compositeId }
        )
        if let existing = try? mainContext.fetch(descriptor).first {
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
        // Batch operation: update existing items or insert new ones
        for item in items {
            let descriptor = FetchDescriptor<ProgressItem>(
                predicate: #Predicate { $0.compositeId == item.compositeId }
            )
            if let existing = try? mainContext.fetch(descriptor).first {
                existing.value = item.value
                existing.dateCreated = item.dateCreated
                existing.dateModified = item.dateModified
            } else {
                mainContext.insert(item)
            }
        }
        try mainContext.save()
    }

    public func deleteProgressItem(progressKey: String, id: String) throws {
        if let item = getProgressItem(progressKey: progressKey, id: id) {
            mainContext.delete(item)
            try mainContext.save()
        }
    }

    public func deleteAllProgressItems(progressKey: String) throws {
        let descriptor = FetchDescriptor<ProgressItem>(
            predicate: #Predicate { $0.progressKey == progressKey }
        )
        let allItems = (try? mainContext.fetch(descriptor)) ?? []
        for item in allItems {
            mainContext.delete(item)
        }
        try mainContext.save()
    }
}
