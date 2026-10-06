//
//  VoiceNicheStep.swift
//  Cue Studio
//

import SwiftUI

/// "What do you talk about?": the topics as chips, up to three. Past the limit the rest dim.
struct VoiceNicheStep: View {
    let draft: VoiceSetupDraft
    let onToggle: (Niche) -> Void

    /// The ten topics of the first flight (09 §14b), and any other one this creator already has.
    private var topics: [Niche] {
        Niche.allCases.filter { Niche.offered.contains($0) || draft.isPicked($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8, lineSpacing: 0) {
                ForEach(topics) { niche in
                    let picked = draft.isPicked(niche)
                    Button { onToggle(niche) } label: {
                        FilterChip(label: niche.chipLabel, isSelected: picked, height: 40)
                            .fixedSize()
                            .frame(minHeight: Metrics.hitTarget)
                            .contentShape(Rectangle())
                            .opacity(picked || draft.canAddNiche ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("voiceSetup.niche.\(niche.id)")
                }
            }
            Text("Pick up to \(draft.nicheCap)")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
        }
    }
}
