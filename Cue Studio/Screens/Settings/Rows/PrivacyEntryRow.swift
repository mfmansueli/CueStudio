//
//  PrivacyEntryRow.swift
//  Cue Studio
//

import SwiftUI

/// The rows of Settings › Privacy & AI data: the two switches, the permissions, and "Delete my Cue data" (asked about by the page's list,
/// `confirmsDataErase()`).
struct PrivacyEntryRow: View {
    let entry: SettingsEntry

    @Environment(PrivacyPreferencesService.self) private var privacy
    @Environment(DataEraserService.self) private var eraser

    var body: some View {
        @Bindable var privacy = privacy
        content(privacy: $privacy)
            .accessibilityIdentifier("settings.\(entry.rawValue)")
    }

    @ViewBuilder
    private func content(privacy: Bindable<PrivacyPreferencesService>) -> some View {
        switch entry {
        case .onDeviceAI:
            SettingsListToggle(title: entry.title, detail: entry.detail, isOn: privacy.usesOnDeviceAI)
        case .helpImprove:
            SettingsListToggle(title: entry.title, detail: entry.detail, isOn: privacy.helpsImproveCue)
        case .permissions:
            NavigationLink(value: SettingsRoute.permissions) {
                SettingsValueLabel(title: entry.title, value: String(localized: "Camera · Mic · Speech"))
            }
        case .deleteData:
            Button(entry.title, role: .destructive) { eraser.isConfirming = true }
                .frame(minHeight: Metrics.listRowContent)
        default:
            EmptyView()
        }
    }
}
