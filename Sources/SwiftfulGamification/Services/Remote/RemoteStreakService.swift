//
//  RemoteStreakService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

@MainActor
public protocol RemoteStreakService: Sendable {
    func streamCurrentStreak(userId: String) -> AsyncStream<CurrentStreakData?>
    func addEvent(userId: String, event: StreakEvent) async throws
    func getAllEvents(userId: String) async throws -> [StreakEvent]
    func deleteAllEvents(userId: String) async throws
}
