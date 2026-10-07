//
//  VoiceReachField.swift
//  Cue Studio
//

import SwiftUI

/// Personality · where it goes: where they post and how long their videos usually are. The length is what Cue writes for when the creator
/// doesn't ask for another.
struct VoiceReachField: View {
    @Environment(CreatorProfileService.self) private var profile

    private var current: CreatorProfile { profile.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                VoiceFieldLabel(String(localized: "Where you post"))
                VoiceOptionChips(
                    options: Platform.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) },
                    isSelected: { option in current.reach.platforms.contains { $0.rawValue == option.id } },
                    onTap: { option in
                        guard let platform = Platform(rawValue: option.id) else { return }
                        profile.togglePlatform(platform)
                    },
                    identifier: "voice.platform"
                )
            }
            VStack(alignment: .leading, spacing: 8) {
                VoiceFieldLabel(String(localized: "Usual length"))
                VoiceSegmentedChoice(
                    values: VideoLength.allCases, selection: current.reach.length, label: \.label,
                    onPick: { profile.answer(.length, with: VoiceOption(id: $0.rawValue, label: $0.label)) }, identifier: "voice.length"
                )
                Text("When you don’t pick a length, Cue writes for this one.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 4)
            }
        }
    }
}
