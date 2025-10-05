//
//  RemoteExperiencePointsService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation

@MainActor
public protocol RemoteExperiencePointsService: Sendable {
    func streamCurrentExperiencePoints(userId: String, experienceId: String) -> AsyncThrowingStream<CurrentExperiencePointsData, Error>
    func updateCurrentExperiencePoints(userId: String, experienceId: String, data: CurrentExperiencePointsData) async throws
    func calculateExperiencePoints(userId: String, experienceId: String) async throws
    func addEvent(userId: String, experienceId: String, event: ExperiencePointsEvent) async throws
    func getAllEvents(userId: String, experienceId: String) async throws -> [ExperiencePointsEvent]
    func deleteAllEvents(userId: String, experienceId: String) async throws
}
