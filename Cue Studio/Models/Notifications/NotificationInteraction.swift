//
//  NotificationInteraction.swift
//  Cue Studio
//

import Foundation

/// A tap on one of Cue's notifications, as plain values taken from the system's response before it crosses to the main actor.
/// `id` is the delivered notification (its request and the moment it was delivered), so a callback the system repeats is handled once.
nonisolated struct NotificationInteraction: Hashable, Sendable {
    var requestID: String
    /// The JSON of `NotificationPayload`, as the notification carried it; unread until it is validated.
    var payloadText: String?
    var deliveredAt: Date

    var id: String { "\(requestID)@\(Int(deliveredAt.timeIntervalSince1970))" }

    var payload: NotificationPayload? { NotificationPayload.decode(payloadText) }
}
