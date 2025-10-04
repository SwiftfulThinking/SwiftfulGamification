//
//  RemoteStreakService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

@MainActor
public protocol RemoteStreakService: Sendable {
    func streamCurrentStreak(userId: String) -> AsyncThrowingStream<CurrentStreakData?, Error>
    func updateCurrentStreak(userId: String, streak: CurrentStreakData) async throws
    func calculateStreak(userId: String) async throws
    func addEvent(userId: String, event: StreakEvent) async throws
    func getAllEvents(userId: String) async throws -> [StreakEvent]
    func deleteAllEvents(userId: String) async throws

    // Freeze management
    func addStreakFreeze(userId: String, freeze: StreakFreeze) async throws
    func useStreakFreeze(userId: String, freezeId: String) async throws
    func getAllStreakFreezes(userId: String) async throws -> [StreakFreeze]
}
