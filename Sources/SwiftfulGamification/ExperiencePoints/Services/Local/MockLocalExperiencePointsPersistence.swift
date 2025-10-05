//
//  MockLocalExperiencePointsPersistence.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public class MockLocalExperiencePointsPersistence: LocalExperiencePointsPersistence {

    private var data: [String: CurrentExperiencePointsData] = [:]

    public init(data: CurrentExperiencePointsData? = nil) {
        if let data = data {
            self.data[data.experienceId] = data
        }
    }

    public func getSavedExperiencePointsData(experienceId: String) -> CurrentExperiencePointsData? {
        return data[experienceId]
    }

    public func saveCurrentExperiencePointsData(experienceId: String, _ xpData: CurrentExperiencePointsData?) throws {
        if let xpData = xpData {
            data[experienceId] = xpData
        } else {
            data.removeValue(forKey: experienceId)
        }
    }
}
