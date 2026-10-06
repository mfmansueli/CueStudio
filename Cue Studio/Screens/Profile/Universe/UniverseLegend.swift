//
//  UniverseLegend.swift
//  Cue Studio
//

import SwiftUI

/// The themes under the map (9.2): a 3 × 14 pt bar in the theme's colour (never a dot), its name and its count. A row opens Takes filtered to that
/// theme in that year.
struct UniverseLegend: View {
    let snapshot: UniverseSnapshot
    let onTheme: (OnboardingTopic) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(snapshot.topics.enumerated()), id: \.offset) { index, entry in
                Button { onTheme(entry.topic) } label: {
                    HStack(spacing: 7) {
                        Capsule().fill(OnboardingTopic.color(at: index)).frame(width: 3, height: 12)
                        Text(entry.topic.label).foregroundStyle(Palette.ink)
                        Text("\(entry.count)").foregroundStyle(Palette.inkHint)
                    }
                    .font(.system(size: 12.5))
                    .frame(minHeight: 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("universe.theme.\(index)")
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
