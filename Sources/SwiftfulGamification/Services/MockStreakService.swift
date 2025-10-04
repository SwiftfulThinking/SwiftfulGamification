import Foundation
import Combine

@MainActor
public class MockStreakService: RemoteStreakService, LocalStreakPersistence {

    @Published private var currentStreak: CurrentStreakData? = nil
    private var events: [StreakEvent] = []

    public init(streak: CurrentStreakData? = nil) {
        self.currentStreak = streak
    }

    // MARK: - LocalStreakPersistence

    public func getSavedStreakData() -> CurrentStreakData? {
        return currentStreak
    }

    public func saveCurrentStreakData(_ streak: CurrentStreakData?) throws {
        currentStreak = streak
    }

    // MARK: - RemoteStreakService

    public func streamCurrentStreak(userId: String) -> AsyncStream<CurrentStreakData?> {
        AsyncStream { continuation in
            let task = Task {
                for await value in $currentStreak.values {
                    continuation.yield(value)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func addEvent(userId: String, event: StreakEvent) async throws {
        events.append(event)
    }

    public func getAllEvents(userId: String) async throws -> [StreakEvent] {
        return events
    }

    public func deleteAllEvents(userId: String) async throws {
        events.removeAll()
    }
}
