//
//  NotificationTriggers.swift
//  Cue Studio
//

import SwiftUI

/// What makes the notifications plan again, and nothing else (no timer, no polling): Cue coming to the screen and leaving it, the library,
/// the takes, the share queues and the Logbook changing, a new interface language or time zone (the texts and clock times are written
/// again), the Apple account changing. A remote connecting is Remote Control used for real.
struct NotificationTriggers: ViewModifier {
    let services: AppServices
    /// Cue became active: a tap waiting can be taken.
    let onActive: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    private var notifications: NotificationService { services.notifications }

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .active:
                    notifications.appBecameActive()
                    onActive()
                case .background:
                    notifications.appLeftScreen()
                default:
                    break
                }
            }
            .onChange(of: services.library.scripts.count) { notifications.setNeedsReconcile() }
            .onChange(of: services.takes.takes.count) { notifications.setNeedsReconcile() }
            .onChange(of: services.shareQueue.queues) { notifications.setNeedsReconcile() }
            .onChange(of: services.logbook.entries.count) { notifications.setNeedsReconcile() }
            .onChange(of: services.session.account?.userID) { notifications.setNeedsReconcile() }
            .onChange(of: services.languages.interfaceLanguage) { notifications.setNeedsReconcile(rewritesTexts: true) }
            .onChange(of: services.remote.state.isConnected) { _, connected in
                if connected { notifications.recordUse(.remoteControl) }
            }
            .task {
                // A new time zone: reminders keep their clock time, and every scheduled time is resolved again in it.
                for await _ in NotificationCenter.default.notifications(named: .NSSystemTimeZoneDidChange) {
                    notifications.setNeedsReconcile(rewritesTexts: true)
                }
            }
    }
}
