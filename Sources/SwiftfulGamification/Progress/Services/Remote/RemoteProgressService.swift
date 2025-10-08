//
//  RemoteProgressService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public protocol RemoteProgressService: Sendable {
    func getAllProgressItems(userId: String, progressKey: String) async throws -> [ProgressItem]
    func streamProgressUpdates(userId: String, progressKey: String) -> (
        updates: AsyncThrowingStream<ProgressItem, Error>,
        deletions: AsyncThrowingStream<String, Error>
    )
    func updateProgress(userId: String, progressKey: String, item: ProgressItem) async throws
    func deleteProgress(userId: String, progressKey: String, id: String) async throws
    func deleteAllProgress(userId: String, progressKey: String) async throws
}
