//
//  LocalStreakPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

@MainActor
public protocol LocalStreakPersistence {
    func getSavedStreakData(streakId: String) -> CurrentStreakData?
    func saveCurrentStreakData(streakId: String, _ streak: CurrentStreakData?) throws
}
