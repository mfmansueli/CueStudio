//
//  SystemNotificationCenter.swift
//  Cue Studio
//

import Foundation
import UserNotifications

/// `UNUserNotificationCenter`, the only place that makes the system's requests. Local notifications only: no server, no push token.
final class SystemNotificationCenter: NotificationCenterClient {
    private var center: UNUserNotificationCenter { .current() }

    func authorization() async -> NotificationAuthorization {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized: .authorized
        case .denied: .denied
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: LocalNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.content.title
        content.body = request.content.body
        content.threadIdentifier = request.payload.category.threadIdentifier
        content.userInfo = [NotificationPayload.userInfoKey: request.payload.encoded()]
        content.interruptionLevel = request.isPassive ? .passive : .active
        content.sound = request.isPassive ? nil : .default
        let trigger: UNNotificationTrigger
        switch request.trigger {
        case .at(let time):
            trigger = UNCalendarNotificationTrigger(dateMatching: time.components, repeats: false)
        case .weekly(let weekday, let hour, let minute):
            trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: minute, weekday: weekday), repeats: true)
        case .soon:
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        }
        try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(NotificationIdentifier.prefix) }
    }

    func removePending(_ identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDelivered(_ identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
