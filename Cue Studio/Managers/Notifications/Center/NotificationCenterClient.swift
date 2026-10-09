//
//  NotificationCenterClient.swift
//  Cue Studio
//

import Foundation

/// The system's notification center, as Cue uses it (`SystemNotificationCenter`; tests and UI tests use their own). Only Cue's own
/// requests are touched: every identifier starts with `NotificationIdentifier.prefix`.
protocol NotificationCenterClient: AnyObject {
    /// What iOS allows now (it changes in Settings, outside Cue).
    func authorization() async -> NotificationAuthorization
    /// Asks the creator (the system's question). True when allowed. iOS asks only once: after a no, it answers no without asking.
    func requestAuthorization() async throws -> Bool
    /// Hands a request to the system; the same identifier replaces the one before. Throws when the system refuses it.
    func add(_ request: LocalNotificationRequest) async throws
    /// The identifiers of the requests waiting to be delivered.
    func pendingIdentifiers() async -> [String]
    func removePending(_ identifiers: [String])
    func removeDelivered(_ identifiers: [String])
}
