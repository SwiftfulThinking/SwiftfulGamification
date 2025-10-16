//
//  RemoteExperiencePointsService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public protocol RemoteExperiencePointsService: Sendable {
    func streamCurrentExperiencePoints(userId: String, experienceKey: String) -> AsyncThrowingStream<CurrentExperiencePointsData, Error>
    func updateCurrentExperiencePoints(userId: String, experienceKey: String, data: CurrentExperiencePointsData) async throws
    func calculateExperiencePoints(userId: String, experienceKey: String, timezone: String?) async throws
    func addEvent(userId: String, experienceKey: String, event: ExperiencePointsEvent) async throws
    func getAllEvents(userId: String, experienceKey: String) async throws -> [ExperiencePointsEvent]
    func deleteAllEvents(userId: String, experienceKey: String) async throws
}
