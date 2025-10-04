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

    @Published private var currentStreaks: [String: CurrentStreakData] = [:]
    private var events: [String: [StreakEvent]] = [:]
    private var freezes: [String: [StreakFreeze]] = [:]

    public init(streak: CurrentStreakData? = nil) {
        if let streak = streak {
            self.currentStreaks[streak.streakId] = streak
        }
    }

    public func streamCurrentStreak(userId: String, streakId: String) -> AsyncThrowingStream<CurrentStreakData, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                // Listen for changes (Combine publisher will emit current value first)
                for await allStreaks in $currentStreaks.values {
                    if let streak = allStreaks[streakId] {
                        continuation.yield(streak)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func updateCurrentStreak(userId: String, streakId: String, streak: CurrentStreakData) async throws {
        currentStreaks[streakId] = streak
    }

    public func calculateStreak(userId: String, streakId: String) async throws {
        // Mock implementation does nothing - server would trigger Cloud Function
        // The actual calculation happens via the listener when server updates the streak
    }

    public func addEvent(userId: String, streakId: String, event: StreakEvent) async throws {
        var streakEvents = events[streakId] ?? []
        streakEvents.append(event)
        events[streakId] = streakEvents
    }

    public func getAllEvents(userId: String, streakId: String) async throws -> [StreakEvent] {
        return events[streakId] ?? []
    }

    public func deleteAllEvents(userId: String, streakId: String) async throws {
        events[streakId] = []
    }

    // MARK: - Freeze Management

    public func addStreakFreeze(userId: String, streakId: String, freeze: StreakFreeze) async throws {
        var streakFreezes = freezes[streakId] ?? []
        streakFreezes.append(freeze)
        freezes[streakId] = streakFreezes
    }

    public func useStreakFreeze(userId: String, streakId: String, freezeId: String) async throws {
        guard var streakFreezes = freezes[streakId],
              let index = streakFreezes.firstIndex(where: { $0.id == freezeId }) else {
            throw URLError(.badURL)
        }

        let freeze = streakFreezes[index]
        let usedFreeze = StreakFreeze(
            id: freeze.id,
            streakId: freeze.streakId,
            earnedDate: freeze.earnedDate,
            usedDate: Date(),
            expiresAt: freeze.expiresAt
        )

        streakFreezes[index] = usedFreeze
        freezes[streakId] = streakFreezes
    }

    public func getAllStreakFreezes(userId: String, streakId: String) async throws -> [StreakFreeze] {
        return freezes[streakId] ?? []
    }
}
