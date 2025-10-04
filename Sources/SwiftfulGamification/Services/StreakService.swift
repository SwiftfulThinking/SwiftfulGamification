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
        let mockService = MockStreakService(streak: streak)
        self.remote = mockService
        self.local = mockService
    }
}
