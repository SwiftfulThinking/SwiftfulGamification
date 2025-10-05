//
//  LocalExperiencePointsPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public protocol LocalExperiencePointsPersistence {
    func getSavedExperiencePointsData(experienceId: String) -> CurrentExperiencePointsData?
    func saveCurrentExperiencePointsData(experienceId: String, _ data: CurrentExperiencePointsData?) throws
}
