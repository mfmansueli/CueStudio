//
//  InMemoryNotificationCenter.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// UI tests' notification center: the permission is whatever the test launched with (`-uiTestNotificationAuth`) and asking answers at
/// once, with no system prompt; requests are kept in memory (Settings › Notifications › DEBUG lists them). Nothing is ever delivered.
final class InMemoryNotificationCenter: NotificationCenterClient {
    enum Start: String {
        /// Not asked yet; asking allows.
        case notDetermined
        /// Not asked yet; asking is refused.
        case refuses
        case authorized
        case denied
        case provisional
    }

    private var current: NotificationAuthorization
    private let allowsWhenAsked: Bool
    private(set) var requests: [String: LocalNotificationRequest] = [:]

    init(start: Start) {
        switch start {
        case .notDetermined, .refuses: current = .notDetermined
        case .authorized: current = .authorized
        case .denied: current = .denied
        case .provisional: current = .provisional
        }
        allowsWhenAsked = start != .refuses
    }

    func authorization() async -> NotificationAuthorization { current }

    func requestAuthorization() async throws -> Bool {
        guard current == .notDetermined else { return current.canSchedule }
        current = allowsWhenAsked ? .authorized : .denied
        return allowsWhenAsked
    }

    func add(_ request: LocalNotificationRequest) async throws {
        requests[request.identifier] = request
    }

    func pendingIdentifiers() async -> [String] { Array(requests.keys) }

    func removePending(_ identifiers: [String]) {
        for identifier in identifiers { requests[identifier] = nil }
    }

    func removeDelivered(_ identifiers: [String]) {}
}
#endif
