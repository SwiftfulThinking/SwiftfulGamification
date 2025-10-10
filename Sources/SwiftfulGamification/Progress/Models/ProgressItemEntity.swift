//
//  ProgressItemEntity.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import SwiftData

/// SwiftData entity for local persistence of progress items
///
/// **Architecture Note:**
/// This is the persistence layer model used exclusively by SwiftDataProgressPersistence.
/// The public API uses `ProgressItem` (a Sendable struct) for data transfer.
/// Conversion between ProgressItemEntity and ProgressItem happens in the persistence layer.
@Model
final class ProgressItemEntity {
    /// User-provided identifier (e.g., "world1", "level5")
    var id: String

    /// Composite unique identifier for SwiftData: "{progressKey}_{id}"
    /// Prevents conflicts when same ID exists in different progressKeys
    @Attribute(.unique) var compositeId: String

    /// Progress key for grouping items (e.g., "level", "achievements")
    var progressKey: String

    /// Progress value between 0.0 and 1.0
    var value: Double

    /// UTC timestamp when the progress item was created
    var dateCreated: Date

    /// UTC timestamp when the progress item was last modified
    var dateModified: Date

    /// Custom metadata associated with this item (for developer-defined data and filtering)
    var metadata: [String: GamificationDictionaryValue]

    // MARK: - Initialization

    init(
        id: String,
        progressKey: String,
        value: Double,
        dateCreated: Date = Date(),
        dateModified: Date = Date(),
        metadata: [String: GamificationDictionaryValue] = [:]
    ) {
        self.id = id
        self.progressKey = progressKey
        self.compositeId = "\(progressKey)_\(id)"
        self.value = value
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.metadata = metadata
    }

    // MARK: - Conversion

    /// Convert to public ProgressItem model
    func toProgressItem() -> ProgressItem {
        ProgressItem(
            id: id,
            progressKey: progressKey,
            value: value,
            dateCreated: dateCreated,
            dateModified: dateModified,
            metadata: metadata
        )
    }

    /// Create entity from public ProgressItem model
    static func from(_ item: ProgressItem) -> ProgressItemEntity {
        ProgressItemEntity(
            id: item.id,
            progressKey: item.progressKey,
            value: item.value,
            dateCreated: item.dateCreated,
            dateModified: item.dateModified,
            metadata: item.metadata
        )
    }

    /// Update this entity with values from ProgressItem
    func update(from item: ProgressItem) {
        self.id = item.id
        self.progressKey = item.progressKey
        self.compositeId = item.compositeId
        self.value = item.value
        self.dateCreated = item.dateCreated
        self.dateModified = item.dateModified
        self.metadata = item.metadata
    }
}
