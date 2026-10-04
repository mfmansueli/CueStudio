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
                                HStack(spacing: 8) {
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
                                Text(sound.example)
                                    .font(.system(.footnote, design: .serif))
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
}
