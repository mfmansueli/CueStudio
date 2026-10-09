//
//  NotificationPermissionSection.swift
//  Cue Studio
//

import SwiftUI

/// The top of Settings › Notifications: whether iOS lets Cue send notifications, as a switch the creator can flip. iOS keeps the real
/// setting: on while it was never asked brings up its question (once); any other change opens Cue's page in iOS Settings, because an app
/// can't allow or silence itself. The switch always shows what iOS says, and is read again when Cue comes back from Settings.
struct NotificationPermissionSection: View {
    @Environment(NotificationService.self) private var notifications
    @Environment(\.openURL) private var openURL

    /// What the switch shows: what iOS allows, also while a tap waits for iOS or the creator is away in Settings.
    @State private var isAllowed = false

    private var authorization: NotificationAuthorization { notifications.authorization }

    var body: some View {
        Section {
            SettingsListToggle(
                title: String(localized: "Allow notifications"), detail: status,
                isOn: Binding(get: { isAllowed }, set: { wants in
                    isAllowed = wants
                    Task { await change(to: wants) }
                })
            )
            .cardRowBackground(position: .only)
            .accessibilityIdentifier("notifications.permission")
        } header: {
            CueSectionHeader(verbatim: String(localized: "On this iPhone"))
        } footer: {
            Text(footer).accessibilityIdentifier("notifications.permission.footer")
        }
        .onChange(of: authorization, initial: true) { _, new in isAllowed = new.canSchedule }
    }

    private var status: String {
        switch authorization {
        case .authorized, .ephemeral: String(localized: "On")
        case .provisional: String(localized: "Delivered quietly")
        case .denied: String(localized: "Off in iOS Settings")
        case .notDetermined: String(localized: "Not asked yet")
        }
    }

    private var footer: LocalizedStringKey {
        switch authorization {
        case .authorized, .ephemeral: "iOS keeps this setting. Turning it off opens Cue in iOS Settings."
        case .provisional: "Cue’s notifications arrive quietly in Notification Center. Allow them in iOS Settings to see banners."
        case .denied: "Your reminders stay here in Cue. Turning this on opens Cue in iOS Settings."
        case .notDetermined: "Turn it on and iOS asks you once. Cue also asks when you set a reminder."
        }
    }

    private func change(to wants: Bool) async {
        if wants, authorization == .notDetermined {
            if await notifications.requestAuthorizationIfNeeded().canSchedule { notifications.setNeedsReconcile() }
        } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
        isAllowed = notifications.authorization.canSchedule
    }
}
