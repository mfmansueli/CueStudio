//
//  NotificationPermissionCard.swift
//  Cue Studio
//

import SwiftUI

/// What iOS allows, said plainly at the top of Settings › Notifications: not asked yet (Cue asks when something is turned on), off in iOS
/// Settings (reminders stay in Cue; Open Settings is the creator's to tap, Cue never asks again), or delivered quietly.
struct NotificationPermissionCard: View {
    let authorization: NotificationAuthorization

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch authorization {
        case .denied:
            VStack(alignment: .leading, spacing: 10) {
                Label("Notifications are off for Cue", systemImage: "bell.slash")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text("Your reminders stay here in Cue. To get them on time, allow notifications for Cue in iOS Settings.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.cueSecondary(expands: false))
                .accessibilityIdentifier("notifications.openSettings")
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("notifications.denied")
        case .notDetermined:
            note("Cue asks iOS for permission when you set a reminder or turn something on here.", id: "notifications.notAsked")
        case .provisional:
            note("Cue’s notifications arrive quietly in Notification Center. Allow them in iOS Settings to see banners.", id: "notifications.provisional")
        case .authorized, .ephemeral:
            EmptyView()
        }
    }

    private func note(_ text: LocalizedStringKey, id: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Palette.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 6)
            .accessibilityIdentifier(id)
    }
}
