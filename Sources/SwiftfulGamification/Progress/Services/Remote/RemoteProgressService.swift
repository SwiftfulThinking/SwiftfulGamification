//
//  RemoteProgressService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public protocol RemoteProgressService: Sendable {
    func getAllProgressItems(userId: String) async throws -> [ProgressItem]
    func streamProgressUpdates(userId: String) -> AsyncThrowingStream<ProgressItem, Error>
    func updateProgress(userId: String, item: ProgressItem) async throws
    func deleteProgress(userId: String, id: String) async throws
    func deleteAllProgress(userId: String) async throws
}
