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
            self.streaks[streak.streakKey] = streak
        }
    }

    public func getSavedStreakData(streakKey: String) -> CurrentStreakData? {
        return streaks[streakKey]
    }

    public func saveCurrentStreakData(streakKey: String, _ streak: CurrentStreakData?) throws {
        if let streak = streak {
            streaks[streakKey] = streak
        } else {
            streaks.removeValue(forKey: streakKey)
        }
    }
}
