//
//  NotificationCenterDelegate.swift
//  Cue Studio
//

import Foundation
import UserNotifications

/// The system's notification delegate, set in `CueStudioApp.init` (before launch finishes, so a tap that launched Cue reaches it). It only
/// copies what it needs into plain values and hands them to `NotificationRouter` on the main actor; the routing is the app's. The system's
/// completion handler is always called on the main thread, once the router is done: the `async` form of these methods called it on the
/// thread they returned on, a background one, and UIKit's assertion ended the app on every tap of a notification (crash of 14/10/2026,
/// `-[UIApplication _performBlockAfterCATransactionCommitSynchronizes:]`).
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // The system's block isn't marked Sendable; it is only ever called once, on the main actor.
        nonisolated(unsafe) let complete = completionHandler
        // Only a tap on the notification opens something; Cue registers no other action and is never told of a dismissal.
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            Task { @MainActor in complete() }
            return
        }
        let request = response.notification.request
        let interaction = NotificationInteraction(
            requestID: request.identifier,
            payloadText: request.content.userInfo[NotificationPayload.userInfoKey] as? String,
            deliveredAt: response.notification.date
        )
        Task { @MainActor in
            NotificationRouter.shared.receive(interaction)
            complete()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        nonisolated(unsafe) let complete = completionHandler
        let request = notification.request
        let payload = request.content.userInfo[NotificationPayload.userInfoKey] as? String
        let identifier = request.identifier
        Task { @MainActor in
            switch NotificationRouter.shared.presentation(payloadText: payload, requestID: identifier) {
            case .banner: complete([.banner, .list, .sound])
            case .listOnly: complete([.list])
            case .hidden: complete([])
            }
        }
    }
}
