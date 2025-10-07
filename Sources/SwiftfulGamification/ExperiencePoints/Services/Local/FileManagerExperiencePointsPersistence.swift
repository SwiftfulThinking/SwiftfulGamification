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

    public func getSavedExperiencePointsData(experienceKey: String) -> CurrentExperiencePointsData? {
        let key = "current_xp_\(experienceKey)"
        return try? FileManager.getDocument(key: key)
    }

    public func saveCurrentExperiencePointsData(experienceKey: String, _ data: CurrentExperiencePointsData?) throws {
        let key = "current_xp_\(experienceKey)"
        try FileManager.saveDocument(key: key, value: data)
    }
}
