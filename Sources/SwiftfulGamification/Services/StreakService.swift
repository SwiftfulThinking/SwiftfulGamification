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

    public init(streak: CurrentStreakData? = nil) {
        self.remote = MockRemoteStreakService(streak: streak)
        self.local = MockLocalStreakPersistence(streak: streak)
    }
}
