//
//  MockRemoteStreakService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation
import Combine

@MainActor
public class MockRemoteStreakService: RemoteStreakService {

    @Published private var currentStreak: CurrentStreakData?
    private var events: [StreakEvent] = []
    private var freezes: [StreakFreeze] = []

    public init(streak: CurrentStreakData? = nil) {
        self.currentStreak = streak
    }

    public func streamCurrentStreak(userId: String) -> AsyncStream<CurrentStreakData?> {
        AsyncStream { continuation in
            let task = Task {
                for await value in $currentStreak.values {
                    continuation.yield(value)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func addEvent(userId: String, event: StreakEvent) async throws {
        events.append(event)
    }

    public func getAllEvents(userId: String) async throws -> [StreakEvent] {
        return events
    }

    public func deleteAllEvents(userId: String) async throws {
        events.removeAll()
    }

    // MARK: - Freeze Management

    public func addStreakFreeze(userId: String, freeze: StreakFreeze) async throws {
        freezes.append(freeze)
    }

    public func useStreakFreeze(userId: String, freezeId: String) async throws {
        guard let index = freezes.firstIndex(where: { $0.id == freezeId }) else {
            throw URLError(.badURL)
        }

        let freeze = freezes[index]
        let usedFreeze = StreakFreeze(
            id: freeze.id,
            streakId: freeze.streakId,
            userId: freeze.userId,
            earnedDate: freeze.earnedDate,
            usedDate: Date(),
            expiresAt: freeze.expiresAt
        )

        freezes[index] = usedFreeze
    }

    public func getAllStreakFreezes(userId: String) async throws -> [StreakFreeze] {
        return freezes
    }
}
