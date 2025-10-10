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

    public init() {
        // swiftlint:disable:next force_try
        self.container = try! ModelContainer(for: ProgressItemEntity.self)
    }

    public func getProgressItem(progressKey: String, id: String) -> ProgressItem? {
        let compositeId = "\(progressKey)_\(id)"
        let descriptor = FetchDescriptor<ProgressItemEntity>(
            predicate: #Predicate { $0.compositeId == compositeId }
        )
        guard let entity = try? mainContext.fetch(descriptor).first else {
            return nil
        }
        return entity.toProgressItem()
    }

    public func getAllProgressItems(progressKey: String) -> [ProgressItem] {
        let descriptor = FetchDescriptor<ProgressItemEntity>(
            predicate: #Predicate { $0.progressKey == progressKey }
        )
        let entities = (try? mainContext.fetch(descriptor)) ?? []
        return entities.map { $0.toProgressItem() }
    }

    public func saveProgressItem(_ item: ProgressItem) throws {
        // Check if item already exists using compositeId
        let descriptor = FetchDescriptor<ProgressItemEntity>(
            predicate: #Predicate { $0.compositeId == item.compositeId }
        )
        if let existing = try? mainContext.fetch(descriptor).first {
            // Update existing entity
            existing.update(from: item)
        } else {
            // Insert new entity
            let entity = ProgressItemEntity.from(item)
            mainContext.insert(entity)
        }
        try mainContext.save()
    }

    public func saveProgressItems(_ items: [ProgressItem]) throws {
        // Batch operation: update existing items or insert new ones
        for item in items {
            let descriptor = FetchDescriptor<ProgressItemEntity>(
                predicate: #Predicate { $0.compositeId == item.compositeId }
            )
            if let existing = try? mainContext.fetch(descriptor).first {
                existing.update(from: item)
            } else {
                let entity = ProgressItemEntity.from(item)
                mainContext.insert(entity)
            }
        }
        try mainContext.save()
    }

    public func deleteProgressItem(progressKey: String, id: String) throws {
        let compositeId = "\(progressKey)_\(id)"
        let descriptor = FetchDescriptor<ProgressItemEntity>(
            predicate: #Predicate { $0.compositeId == compositeId }
        )
        if let entity = try? mainContext.fetch(descriptor).first {
            mainContext.delete(entity)
            try mainContext.save()
        }
    }

    public func deleteAllProgressItems(progressKey: String) throws {
        let descriptor = FetchDescriptor<ProgressItemEntity>(
            predicate: #Predicate { $0.progressKey == progressKey }
        )
        let allEntities = (try? mainContext.fetch(descriptor)) ?? []
        for entity in allEntities {
            mainContext.delete(entity)
        }
        try mainContext.save()
    }
}
