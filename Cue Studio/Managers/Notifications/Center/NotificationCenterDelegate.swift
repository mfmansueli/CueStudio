//
//  NotificationCenterDelegate.swift
//  Cue Studio
//

import Foundation
import UserNotifications

/// The system's notification delegate, set in `CueStudioApp.init` (before launch finishes, so a tap that launched Cue reaches it). It only
/// copies what it needs into plain values and hands them to `NotificationRouter` on the main actor; the routing is the app's.
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        // Only a tap on the notification opens something; Cue registers no other action and is never told of a dismissal.
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let request = response.notification.request
        let interaction = NotificationInteraction(
            requestID: request.identifier,
            payloadText: request.content.userInfo[NotificationPayload.userInfoKey] as? String,
            deliveredAt: response.notification.date
        )
        await NotificationRouter.shared.receive(interaction)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let request = notification.request
        let payload = request.content.userInfo[NotificationPayload.userInfoKey] as? String
        let identifier = request.identifier
        switch await NotificationRouter.shared.presentation(payloadText: payload, requestID: identifier) {
        case .banner: return [.banner, .list, .sound]
        case .listOnly: return [.list]
        case .hidden: return []
        }
    }
}
