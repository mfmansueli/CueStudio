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
        VStack(alignment: .leading, spacing: Metrics.questionGap) {
            VoiceFieldSection(String(localized: "Where you post")) {
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
            VoiceFieldSection(String(localized: "Usual length"), help: String(localized: "Without a length, Cue drafts for this one.")) {
                VoiceSegmentedChoice(
                    values: VideoLength.allCases, selection: current.reach.length, label: \.label,
                    onPick: { profile.answer(.length, with: VoiceOption(id: $0.rawValue, label: $0.label)) }, identifier: "voice.length"
                )
            }
        }
    }
}
