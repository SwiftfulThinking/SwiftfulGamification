//
//  RemoteStreakService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

@MainActor
public protocol RemoteStreakService: Sendable {
    func streamCurrentStreak(userId: String, streakKey: String) -> AsyncThrowingStream<CurrentStreakData, Error>
    func updateCurrentStreak(userId: String, streakKey: String, streak: CurrentStreakData) async throws
    func calculateStreak(userId: String, streakKey: String) async throws
    func addEvent(userId: String, streakKey: String, event: StreakEvent) async throws
    func getAllEvents(userId: String, streakKey: String) async throws -> [StreakEvent]
    func deleteAllEvents(userId: String, streakKey: String) async throws

    // Freeze management
    func addStreakFreeze(userId: String, streakKey: String, freeze: StreakFreeze) async throws
    func useStreakFreeze(userId: String, streakKey: String, freezeId: String) async throws
    func getAllStreakFreezes(userId: String, streakKey: String) async throws -> [StreakFreeze]
}
