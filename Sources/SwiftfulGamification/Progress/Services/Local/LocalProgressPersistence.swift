//
//  LocalProgressPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public protocol LocalProgressPersistence: Sendable {
    /// Get a single progress item by ID
    func getProgressItem(id: String) -> ProgressItem?

    /// Get all progress items
    func getAllProgressItems() -> [ProgressItem]

    /// Save or update a single progress item
    func saveProgressItem(_ item: ProgressItem) throws

    /// Save or update multiple progress items (for bulk load)
    func saveProgressItems(_ items: [ProgressItem]) throws

    /// Delete a progress item by ID
    func deleteProgressItem(id: String) throws

    /// Delete all progress items
    func deleteAllProgressItems() throws
}
