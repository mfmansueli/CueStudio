//
//  VoiceToneStep.swift
//  Cue Studio
//

import SwiftUI

/// "How do you sound?": up to two, each with a line that sounds like it, and a tag on the ones that
/// are common for the kind of creator they said they are.
struct VoiceToneStep: View {
    let draft: VoiceSetupDraft
    let onToggle: (VoiceSound) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 16) {
                ForEach(VoiceSound.allCases) { sound in
                    let picked = draft.isPicked(sound)
                    Button { onToggle(sound) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                // The note goes beside the name when it fits, and under it when it doesn't (never cut off).
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: 8) { name(of: sound) }
                                    VStack(alignment: .leading, spacing: 2) { name(of: sound) }
                                }
                                Text(sound.example)
                                    .font(.footnote)
                                    .italic()
                                    .foregroundStyle(Palette.ink2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VoiceRadio(isOn: picked, isCheck: true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                        .opacity(picked || draft.canAddSound ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(picked ? .isSelected : [])
                    .accessibilityIdentifier("voiceSetup.tone.\(sound.id)")
                }
            }
            Text(draft.sounds.count >= draft.soundCap ? "Up to \(draft.soundCap) · \(draft.sounds.count) of \(draft.soundCap)" : "Pick up to \(draft.soundCap)")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
        }
    }

    /// The tone's name and, for the creator's own kind of video, a note that it is common there.
    @ViewBuilder
    private func name(of sound: VoiceSound) -> some View {
        Text(sound.label)
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.ink)
        if let role = draft.role, role.commonSounds.contains(sound) {
            Text("Common for \(role.label.lowercased())")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.accText)
                .lineLimit(1)
        }
    }
}
