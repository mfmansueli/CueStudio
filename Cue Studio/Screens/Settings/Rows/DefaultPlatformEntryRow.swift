//
//  DefaultPlatformEntryRow.swift
//  Cue Studio
//

import SwiftUI

/// The default network, found by Settings' search ("platform", "TikTok"…): it lives in Profile › Edit profile, where onboarding's choice is
/// changed, so the row shows it and opens that sheet. No page of Settings lists it.
struct DefaultPlatformEntryRow: View {
    let entry: SettingsEntry

    @Environment(CreatorProfileService.self) private var profile
    @State private var editsProfile = false

    var body: some View {
        Button { editsProfile = true } label: {
            SettingsValueLabel(title: entry.title, detail: entry.detail, value: profile.profile.defaultPlatform.label)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $editsProfile) { EditProfileSheet() }
        .accessibilityIdentifier("settings.\(entry.rawValue)")
    }
}
