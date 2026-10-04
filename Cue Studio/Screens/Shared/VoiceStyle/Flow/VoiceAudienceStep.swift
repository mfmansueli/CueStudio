//
//  VoiceAudienceStep.swift
//  Cue Studio
//

import SwiftUI

/// "Who do you talk to?": one of four, as radio rows. The audience decides the words.
struct VoiceAudienceStep: View {
    let draft: VoiceSetupDraft
    let onPick: (Vocabulary) -> Void

    var body: some View {
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
