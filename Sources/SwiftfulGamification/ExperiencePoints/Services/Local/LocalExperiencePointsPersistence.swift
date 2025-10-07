//
//  LocalExperiencePointsPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public protocol LocalExperiencePointsPersistence {
    func getSavedExperiencePointsData(experienceKey: String) -> CurrentExperiencePointsData?
    func saveCurrentExperiencePointsData(experienceKey: String, _ data: CurrentExperiencePointsData?) throws
}
