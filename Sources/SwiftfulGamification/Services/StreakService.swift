import Foundation

@MainActor
public protocol StreakServices {
    var remote: RemoteStreakService { get }
    var local: LocalStreakPersistence { get }
}

@MainActor
public struct MockStreakServices: StreakServices {
    public let remote: RemoteStreakService
    public let local: LocalStreakPersistence

    public init(streakId: String, streak: CurrentStreakData? = nil) {
        let initialStreak = streak ?? CurrentStreakData.blank(streakId: streakId)
        self.remote = MockRemoteStreakService(streak: initialStreak)
        self.local = MockLocalStreakPersistence(streak: initialStreak)
    }
}
