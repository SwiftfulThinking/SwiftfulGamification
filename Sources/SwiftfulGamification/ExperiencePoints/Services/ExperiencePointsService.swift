import Foundation

@MainActor
public protocol ExperiencePointsServices {
    var remote: RemoteExperiencePointsService { get }
    var local: LocalExperiencePointsPersistence { get }
}

@MainActor
public struct MockExperiencePointsServices: ExperiencePointsServices {
    public let remote: RemoteExperiencePointsService
    public let local: LocalExperiencePointsPersistence

    public init(data: CurrentExperiencePointsData? = nil) {
        self.remote = MockRemoteExperiencePointsService(data: data)
        self.local = MockLocalExperiencePointsPersistence(data: data)
    }
}
