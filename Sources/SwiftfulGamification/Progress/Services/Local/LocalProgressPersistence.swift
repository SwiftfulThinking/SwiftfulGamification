//
//  LocalProgressPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public protocol LocalProgressPersistence: Sendable {
    /// Get a single progress item by composite ID (progressKey_id)
    func getProgressItem(progressKey: String, id: String) -> ProgressItem?

    /// Get all progress items for a specific progressKey
    func getAllProgressItems(progressKey: String) -> [ProgressItem]

    /// Save or update a single progress item
    func saveProgressItem(_ item: ProgressItem) throws

    /// Save or update multiple progress items (for bulk load)
    /// Runs on background thread for better performance with large batches
    nonisolated func saveProgressItems(_ items: [ProgressItem]) async throws

    /// Delete a progress item by composite ID (progressKey_id)
    func deleteProgressItem(progressKey: String, id: String) throws

    /// Delete all progress items for a specific progressKey
    /// Runs on background thread for better performance with large datasets
    nonisolated func deleteAllProgressItems(progressKey: String) async throws

    /// Save userId for a specific progressKey
    func saveUserId(_ userId: String, progressKey: String)

    /// Get saved userId for a specific progressKey
    func getUserId(progressKey: String) -> String?
}
