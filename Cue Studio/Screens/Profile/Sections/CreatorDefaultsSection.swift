//
//  CreatorDefaultsSection.swift
//  Cue Studio
//

import SwiftUI

/// What new scripts start with: the platform "Create for" begins on and whether the length goals aim at what earns money. They used to sit in the
/// Profile's sheet; the board's Edit Profile has only the name, the username and the creator type, so they live with the rest of the fine-tuning.
struct CreatorDefaultsSection: View {
    @Environment(CreatorProfileService.self) private var profile

    var body: some View {
        @Bindable var profile = profile
        Section {
            Picker("Default “Create for”", selection: $profile.profile.defaultPlatform) {
                ForEach(Platform.allCases) { Text($0.destinationName).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Palette.ink2)
            .cardRowBackground()
            .accessibilityIdentifier("profile.defaultPlatformPicker")
            Toggle("Monetization goals", isOn: $profile.profile.monetizationGoals)
                .tint(Palette.successText)
                .cardRowBackground()
                .accessibilityIdentifier("profile.monetizationGoalsToggle")
        } header: {
            CueSectionHeader("Creator preferences")
        }
    }
}
