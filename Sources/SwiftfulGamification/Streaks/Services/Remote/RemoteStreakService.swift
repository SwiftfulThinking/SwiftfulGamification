//
//  RemoteStreakService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

@MainActor
public protocol RemoteStreakService: Sendable {
    func streamCurrentStreak(userId: String, streakId: String) -> AsyncThrowingStream<CurrentStreakData, Error>
    func updateCurrentStreak(userId: String, streakId: String, streak: CurrentStreakData) async throws
    func calculateStreak(userId: String, streakId: String) async throws
    func addEvent(userId: String, streakId: String, event: StreakEvent) async throws
    func getAllEvents(userId: String, streakId: String) async throws -> [StreakEvent]
    func deleteAllEvents(userId: String, streakId: String) async throws

    // Freeze management
    func addStreakFreeze(userId: String, streakId: String, freeze: StreakFreeze) async throws
    func useStreakFreeze(userId: String, streakId: String, freezeId: String) async throws
    func getAllStreakFreezes(userId: String, streakId: String) async throws -> [StreakFreeze]
}
