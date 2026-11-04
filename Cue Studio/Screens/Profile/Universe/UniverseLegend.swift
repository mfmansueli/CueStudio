//
//  UniverseLegend.swift
//  Cue Studio
//

import SwiftUI

/// The themes under the map (9.2), in one centred line that wraps when it must (the owner, 04/11/2026: the list sat alone at the left over an
/// empty band): a 3 × 12 pt bar in the theme's colour (never a dot), its name and its count. A theme opens Takes filtered to it in that year.
struct UniverseLegend: View {
    let snapshot: UniverseSnapshot
    let onTheme: (OnboardingTopic) -> Void

    var body: some View {
        FlowLayout(spacing: 16, lineSpacing: 2, alignment: .center) {
            ForEach(Array(snapshot.topics.enumerated()), id: \.offset) { index, entry in
                Button { onTheme(entry.topic) } label: {
                    HStack(spacing: 6) {
                        Capsule().fill(OnboardingTopic.color(at: index)).frame(width: 3, height: 12)
                        Text(entry.topic.label).foregroundStyle(Palette.ink)
                        Text("\(entry.count)").foregroundStyle(Palette.ink2)
                    }
                    .cueFont(12.5)
                    .frame(minHeight: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("universe.theme.\(index)")
            }
        }
        .frame(maxWidth: .infinity)
    }
}
