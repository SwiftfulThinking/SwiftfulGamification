//
//  MockLocalStreakPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

@MainActor
public class MockLocalStreakPersistence: LocalStreakPersistence {

    private var currentStreak: CurrentStreakData?

    public init(streak: CurrentStreakData? = nil) {
        self.currentStreak = streak
    }

    public func getSavedStreakData() -> CurrentStreakData? {
        return currentStreak
    }

    public func saveCurrentStreakData(_ streak: CurrentStreakData?) throws {
        currentStreak = streak
    }
}
