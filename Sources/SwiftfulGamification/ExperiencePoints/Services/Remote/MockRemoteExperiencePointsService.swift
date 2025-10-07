//
//  MockRemoteExperiencePointsService.swift
//  SwiftfulGamification
//
//  Created by Nick Sarno on 2025-10-04.
//

import Foundation
import Combine

@MainActor
public class MockRemoteExperiencePointsService: RemoteExperiencePointsService {

    @Published private var currentData: [String: CurrentExperiencePointsData] = [:]
    private var events: [String: [ExperiencePointsEvent]] = [:]

    public init(data: CurrentExperiencePointsData? = nil) {
        if let data = data {
            self.currentData[data.experienceKey] = data
        }
    }

    public func streamCurrentExperiencePoints(userId: String, experienceKey: String) -> AsyncThrowingStream<CurrentExperiencePointsData, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                // Listen for changes (Combine publisher will emit current value first)
                for await allData in $currentData.values {
                    if let data = allData[experienceKey] {
                        continuation.yield(data)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func updateCurrentExperiencePoints(userId: String, experienceKey: String, data: CurrentExperiencePointsData) async throws {
        currentData[experienceKey] = data
    }

    public func calculateExperiencePoints(userId: String, experienceKey: String) async throws {
        // Mock implementation does nothing - server would trigger Cloud Function
        // The actual calculation happens via the listener when server updates the data
    }

    public func addEvent(userId: String, experienceKey: String, event: ExperiencePointsEvent) async throws {
        var experienceEvents = events[experienceKey] ?? []
        experienceEvents.append(event)
        events[experienceKey] = experienceEvents
    }

    public func getAllEvents(userId: String, experienceKey: String) async throws -> [ExperiencePointsEvent] {
        return events[experienceKey] ?? []
    }

    public func deleteAllEvents(userId: String, experienceKey: String) async throws {
        events[experienceKey] = []
    }
}
