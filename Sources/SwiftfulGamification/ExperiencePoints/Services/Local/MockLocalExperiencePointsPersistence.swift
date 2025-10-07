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
            self.data[data.experienceKey] = data
        }
    }

    public func getSavedExperiencePointsData(experienceKey: String) -> CurrentExperiencePointsData? {
        return data[experienceKey]
    }

    public func saveCurrentExperiencePointsData(experienceKey: String, _ xpData: CurrentExperiencePointsData?) throws {
        if let xpData = xpData {
            data[experienceKey] = xpData
        } else {
            data.removeValue(forKey: experienceKey)
        }
    }
}
