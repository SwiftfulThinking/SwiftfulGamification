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

    // MARK: - Background Operations

    /// Save or update multiple progress items (runs on background thread for better performance)
    /// Uses batch fetch optimization: 1 query instead of N queries
    nonisolated public func saveProgressItems(_ items: [ProgressItem]) async throws {
        guard !items.isEmpty else { return }

        // Create background context - this runs off the main actor
        let backgroundContext = ModelContext(container)

        // Batch fetch optimization: fetch all existing items once instead of N queries
        let progressKey = items[0].progressKey
        let descriptor = FetchDescriptor<ProgressItemEntity>(
            predicate: #Predicate { $0.progressKey == progressKey }
        )
        let existingEntities = (try? backgroundContext.fetch(descriptor)) ?? []

        // Create lookup dictionary for O(1) access
        var existingByCompositeId: [String: ProgressItemEntity] = [:]
        for entity in existingEntities {
            existingByCompositeId[entity.compositeId] = entity
        }

        // Update existing or insert new
        for item in items {
            if let existing = existingByCompositeId[item.compositeId] {
                existing.update(from: item)
            } else {
                let entity = ProgressItemEntity.from(item)
                backgroundContext.insert(entity)
            }
        }

        // Single save for all operations
        try backgroundContext.save()
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

    /// Delete all progress items for a specific progressKey (runs on background thread)
    nonisolated public func deleteAllProgressItems(progressKey: String) async throws {
        // Create background context - this runs off the main actor
        let backgroundContext = ModelContext(container)

        let descriptor = FetchDescriptor<ProgressItemEntity>(
            predicate: #Predicate { $0.progressKey == progressKey }
        )
        let allEntities = (try? backgroundContext.fetch(descriptor)) ?? []
        for entity in allEntities {
            backgroundContext.delete(entity)
        }
        try backgroundContext.save()
    }
}
