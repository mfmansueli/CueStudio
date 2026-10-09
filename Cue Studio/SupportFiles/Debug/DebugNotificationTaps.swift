//
//  DebugNotificationTaps.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// `-uiTestNotificationTap <scenario>`: Cue launches as if it had been opened from one of its notifications (a cold launch), on the sample
/// data. The tap goes through `NotificationRouter` like the system's, so the same checks run: once per delivery, payload version, objects
/// that still exist. `duplicate` sends the same tap twice; `invalid` a payload this build can't read; `deletedScript` a script that is gone.
enum DebugNotificationTaps {
    private static let deliveredAt = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    static func interactions(for scenario: String, services: AppServices) -> [NotificationInteraction] {
        let takes = services.takes.takes
        let take = takes.first { $0.scriptID == SampleScripts.morningHabits.id && $0.number == 3 } ?? takes.first
        let ready = services.library.scripts.first { script in !takes.contains { $0.scriptID == script.id } && script.isFinished }
        func tap(_ payload: NotificationPayload) -> NotificationInteraction {
            NotificationInteraction(requestID: "cue.debug.\(scenario)", payloadText: payload.encoded(), deliveredAt: deliveredAt)
        }
        switch scenario {
        case "script":
            guard let ready else { return [] }
            return [tap(NotificationPayload(campaign: .readyToRecord, destination: .script(ready.id), projectKey: ProjectKey.script(ready.id)))]
        case "cleanUp":
            guard let take else { return [] }
            return [tap(NotificationPayload(
                campaign: .feature, feature: .cleanUp, destination: .takeEditor(take.id, tool: .cleanUp), projectKey: ProjectKey.of(take: take)
            ))]
        case "share":
            guard let take else { return [] }
            return [tap(NotificationPayload(campaign: .incompleteSharing, destination: .shareQueue(takeID: take.id, network: nil)))]
        case "deletedScript":
            return [tap(NotificationPayload(campaign: .readyToRecord, destination: .script(UUID())))]
        case "invalid":
            return [NotificationInteraction(requestID: "cue.debug.invalid", payloadText: "{\"version\": 99}", deliveredAt: deliveredAt)]
        case "duplicate":
            let once = tap(NotificationPayload(campaign: .routine, destination: .notificationSettings))
            return [once, once]
        case "routine":
            return [tap(NotificationPayload(campaign: .routine, destination: .nextAction))]
        case "logbook":
            return [tap(NotificationPayload(campaign: .savedIdea, destination: .logbook(entryID: nil)))]
        case "universe":
            return [tap(NotificationPayload(campaign: .feature, feature: .yourUniverse, destination: .universe))]
        default:
            return []
        }
    }
}
#endif
