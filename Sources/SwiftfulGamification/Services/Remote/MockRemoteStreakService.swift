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
}
