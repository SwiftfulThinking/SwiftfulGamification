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
            self.currentStreaks[streak.streakKey] = streak
        }
    }

    public func streamCurrentStreak(userId: String, streakKey: String) -> AsyncThrowingStream<CurrentStreakData, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                // Listen for changes (Combine publisher will emit current value first)
                for await allStreaks in $currentStreaks.values {
                    if let streak = allStreaks[streakKey] {
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

    public func updateCurrentStreak(userId: String, streakKey: String, streak: CurrentStreakData) async throws {
        currentStreaks[streakKey] = streak
    }

    public func calculateStreak(userId: String, streakKey: String) async throws {
        // Mock implementation does nothing - server would trigger Cloud Function
        // The actual calculation happens via the listener when server updates the streak
    }

    public func addEvent(userId: String, streakKey: String, event: StreakEvent) async throws {
        var streakEvents = events[streakKey] ?? []
        streakEvents.append(event)
        events[streakKey] = streakEvents
    }

    public func getAllEvents(userId: String, streakKey: String) async throws -> [StreakEvent] {
        return events[streakKey] ?? []
    }

    public func deleteAllEvents(userId: String, streakKey: String) async throws {
        events[streakKey] = []
    }

    // MARK: - Freeze Management

    public func addStreakFreeze(userId: String, streakKey: String, freeze: StreakFreeze) async throws {
        var streakFreezes = freezes[streakKey] ?? []
        streakFreezes.append(freeze)
        freezes[streakKey] = streakFreezes
    }

    public func useStreakFreeze(userId: String, streakKey: String, freezeId: String) async throws {
        guard var streakFreezes = freezes[streakKey],
              let index = streakFreezes.firstIndex(where: { $0.id == freezeId }) else {
            throw URLError(.badURL)
        }

        let freeze = streakFreezes[index]
        let usedFreeze = StreakFreeze(
            id: freeze.id,
            streakKey: freeze.streakKey,
            earnedDate: freeze.earnedDate,
            usedDate: Date(),
            expiresAt: freeze.expiresAt
        )

        streakFreezes[index] = usedFreeze
        freezes[streakKey] = streakFreezes
    }

    public func getAllStreakFreezes(userId: String, streakKey: String) async throws -> [StreakFreeze] {
        return freezes[streakKey] ?? []
    }
}
