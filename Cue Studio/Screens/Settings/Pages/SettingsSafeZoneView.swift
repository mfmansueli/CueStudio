//
//  SettingsSafeZoneView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Prompter › Safe zone: whether the camera shows where the network's buttons and captions cover the frame. The zone always
/// follows the network the video is recorded for; the creator's own Custom zone is set in the recorder's Aa › Window.
struct SettingsSafeZoneView: View {
    let bindings: SettingsBindings

    var body: some View {
        List {
            Section {
                SettingsListToggle(
                    title: String(localized: "Show safe zone"),
                    detail: String(localized: "Where each app's buttons and captions cover the frame"),
                    isOn: bindings.camera.showsSafeZones
                )
                .accessibilityIdentifier("settings.safeZoneToggle")
                .cardRowBackground()
            } footer: {
                Text("A guide, not a guarantee · Never recorded")
            }
        }
        .cueGroupedList()
        .accessibilityIdentifier("settings.safeZonePage")
        .navigationTitle("Safe zone")
        .navigationBarTitleDisplayMode(.inline)
        .contentMargins(.top, 0, for: .scrollContent)
    }
}
