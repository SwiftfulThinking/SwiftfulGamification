//
//  MockLocalStreakPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

@MainActor
public class MockLocalStreakPersistence: LocalStreakPersistence {

    private var streaks: [String: CurrentStreakData] = [:]

    public init(streak: CurrentStreakData? = nil) {
        if let streak = streak {
            self.streaks[streak.streakId] = streak
        }
    }

    public func getSavedStreakData(streakId: String) -> CurrentStreakData? {
        return streaks[streakId]
    }

    public func saveCurrentStreakData(streakId: String, _ streak: CurrentStreakData?) throws {
        if let streak = streak {
            streaks[streakId] = streak
        } else {
            streaks.removeValue(forKey: streakId)
        }
    }
}
