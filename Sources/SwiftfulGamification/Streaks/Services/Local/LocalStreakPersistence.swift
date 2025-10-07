//
//  LocalStreakPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-09-30.
//

import Foundation

@MainActor
public protocol LocalStreakPersistence {
    func getSavedStreakData(streakKey: String) -> CurrentStreakData?
    func saveCurrentStreakData(streakKey: String, _ streak: CurrentStreakData?) throws
}
