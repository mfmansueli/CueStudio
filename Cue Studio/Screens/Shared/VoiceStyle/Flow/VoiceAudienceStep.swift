//
//  VoiceAudienceStep.swift
//  Cue Studio
//

import SwiftUI

/// "Who do you talk to?": one of four, as radio rows, then how much they already know (New to it · Some basics · Experienced, v30 · 2.3).
/// The audience decides the words.
struct VoiceAudienceStep: View {
    let draft: VoiceSetupDraft
    let onPick: (Vocabulary) -> Void
    let onLevel: (AudienceLevel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            audience
            level
        }
    }

    private var level: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How much do they already know?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
            HStack(spacing: 6) {
                ForEach(AudienceLevel.allCases) { level in
                    let picked = draft.isPicked(level)
                    Button { onLevel(level) } label: {
                        Text(level.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(picked ? Palette.accInk : Palette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                            .background(picked ? Palette.chipOn : Palette.fill, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(picked ? .isSelected : [])
                    .accessibilityIdentifier("voiceSetup.level.\(level.rawValue)")
                }
            }
        }
    }

    private var audience: some View {
        GroupedCard(background: Palette.surface2, radius: 16, dividerInset: 16) {
            ForEach(Vocabulary.allCases) { vocabulary in
                let picked = draft.isPicked(vocabulary)
                Button { onPick(vocabulary) } label: {
                    HStack(spacing: 12) {
                        Text(vocabulary.audienceLabel)
                            .font(.body)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        VoiceRadio(isOn: picked)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(picked ? .isSelected : [])
                .accessibilityIdentifier("voiceSetup.audience.\(vocabulary.id)")
            }
        }
    }
}
