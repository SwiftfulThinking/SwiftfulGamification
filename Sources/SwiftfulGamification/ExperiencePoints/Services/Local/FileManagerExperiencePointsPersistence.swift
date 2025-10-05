//
//  FileManagerExperiencePointsPersistence.swift
//  SwiftfulGamification
//
//  Production-ready local persistence using FileManager
//

import Foundation

@MainActor
public struct FileManagerExperiencePointsPersistence: LocalExperiencePointsPersistence {

    public init() { }

    public func getSavedExperiencePointsData(experienceId: String) -> CurrentExperiencePointsData? {
        let key = "current_xp_\(experienceId)"
        return try? FileManager.getDocument(key: key)
    }

    public func saveCurrentExperiencePointsData(experienceId: String, _ data: CurrentExperiencePointsData?) throws {
        let key = "current_xp_\(experienceId)"
        try FileManager.saveDocument(key: key, value: data)
    }
}
