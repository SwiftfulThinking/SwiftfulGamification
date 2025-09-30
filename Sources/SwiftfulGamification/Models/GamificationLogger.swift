import Foundation

@MainActor
public protocol GamificationLogger {
    func trackEvent(event: GamificationLogEvent)
    func addUserProperties(dict: [String: Any], isHighPriority: Bool)
}

public protocol GamificationLogEvent {
    var eventName: String { get }
    var parameters: [String: Any]? { get }
    var type: GamificationLogType { get }
}

public enum GamificationLogType: Int, CaseIterable, Sendable {
    case info = 0
    case analytic = 1
    case warning = 2
    case severe = 3
}
