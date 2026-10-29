import Foundation

@MainActor
public protocol ProgressServices {
    var remote: RemoteProgressService { get }
    var local: LocalProgressPersistence { get }
}

@MainActor
public struct MockProgressServices: ProgressServices {
    public let remote: RemoteProgressService
    public let local: LocalProgressPersistence

    public init(items: [ProgressItem] = [], loadDelay: TimeInterval = 0) {
        self.remote = MockRemoteProgressService(items: items, loadDelay: loadDelay)
        self.local = MockLocalProgressPersistence(items: items)
    }
}
