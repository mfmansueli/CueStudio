//
//  EditProfilePreferences.swift
//  Cue Studio
//

import SwiftUI

/// What new scripts start with, in Edit Profile: the platform "Create for" begins on and whether the length goals aim at what earns money. Like the
/// rest of the sheet they are kept when Done is tapped.
struct EditProfilePreferences: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        VStack(spacing: 0) {
            Menu {
                Picker("Default “Create for”", selection: $draft.defaultPlatform) {
                    ForEach(Platform.allCases) { Text($0.destinationName).tag($0) }
                }
            } label: {
                HStack(spacing: 12) {
                    Text("Default “Create for”").font(.system(size: 17)).foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Text(draft.defaultPlatform.destinationName).font(.system(size: 17)).foregroundStyle(Palette.ink2)
                    Image(systemName: "chevron.up.chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink3)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("profile.defaultPlatformPicker")
            Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 16)
            Toggle("Monetization goals", isOn: $draft.monetizationGoals)
                .font(.system(size: 17))
                .tint(Palette.successText)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .accessibilityIdentifier("profile.monetizationGoalsToggle")
        }
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
