//
//  ScriptRow.swift
//  Cue Studio
//

import SwiftUI

/// A script on the Scripts list (v29): the title, with a small ✦ in the colour of its topic's world after it, a mono line ("● TIKTOK",
/// `ScriptRowLine`) and the one way forward for its state: "● REC" when it is ready, a "›" for a draft, "×3 ›" (its videos, in Takes) once
/// it has
/// takes. A tap anywhere else on the row opens the script's page, whatever its state. While Scripts selects, the way forward gives
/// its place to nothing and the row starts with its selection mark (`ScriptSelectionMark`), inside the card.
struct ScriptRow: View {
    let script: Script
    let state: ScriptState
    let line: ScriptRowLine
    let takeCount: Int
    /// The name of the script's topic and the colour of its world; nil until it has one.
    let topic: (name: String, color: Color)?
    let showsTrailing: Bool
    /// Whether the script is picked while Scripts selects; nil when it doesn't.
    var isSelected: Bool?
    let onRecord: () -> Void
    let onTakes: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At the accessibility text sizes the title and its line take more lines instead of being cut short.
        let large = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: 12) {
            if let isSelected {
                ScriptSelectionMark(isSelected: isSelected)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(titleWords)
                    .cueFont(15.5, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(large ? 4 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(script.displayTitle))
                    .accessibilityValue(topic?.name ?? "")
                HStack(spacing: 6) {
                    PlatformDot(color: script.platform.tint, isSmall: true)
                    Text(line.values.joined(separator: " · "))
                        .monoFont(size: 10, weight: .semibold)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Palette.inkHint)
                        .lineLimit(large ? 2 : 1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(line.values.joined(separator: ", ")))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsTrailing { trailing }
        }
        .padding(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 12))
        .frame(minHeight: 58)
        .accessibilityElement(children: .contain)
    }

    /// The title, and its topic as a ✦ in the world's colour after the last word: the owner's pick in place of the bar that started the card
    /// (30/10/2026). It wraps with the words, so every title starts at the same edge, with a topic or without.
    private var titleWords: AttributedString {
        var words = AttributedString(script.displayTitle)
        guard let topic else { return words }
        var star = AttributedString("\u{00A0}✦")
        star.foregroundColor = topic.color
        words.append(star)
        return words
    }

    @ViewBuilder
    private var trailing: some View {
        switch state {
        case .ready:
            RecPill(action: onRecord, accessibilityIdentifier: "row.recordButton")
        case .draft:
            // Only the arrow: the whole row opens the draft (the owner took "Continue" off, 30/10/2026).
            Image(systemName: "chevron.right")
                .cueFont(14, weight: .semibold)
                .foregroundStyle(Palette.ink2)
                .accessibilityLabel(Text("Continue"))
                .accessibilityIdentifier("row.continue")
        case .recorded:
            Button(action: onTakes) {
                Text(verbatim: "×\(takeCount) ›")
                    .cueFont(13.5, weight: .semibold)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .fixedSize()
                    // The 44 pt around the count, so it is a target of its own beside the row's tap.
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Takes"))
            .accessibilityValue(Text(verbatim: "\(takeCount)"))
            .accessibilityIdentifier("row.takes")
        }
    }
}

#if DEBUG
#Preview {
    List {
        ScriptRow(
            script: SampleScripts.lampReview, state: .ready,
            line: ScriptRowLine(
                script: SampleScripts.lampReview, state: .ready, takes: [], hasDraft: { _ in false }
            ),
            takeCount: 0, topic: ("Tech", Palette.World.sky), showsTrailing: true, onRecord: {}, onTakes: {}
        )
    }
    .previewEnvironment()
}
#endif
