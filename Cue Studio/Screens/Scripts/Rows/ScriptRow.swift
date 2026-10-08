//
//  ScriptRow.swift
//  Cue Studio
//

import SwiftUI

/// A script on the Scripts list (v29): the topic's bar, the title, a mono line ("● TIKTOK · 0:47 · 4 CUES") and the one
/// way forward for its state: "● REC" when it is ready, "Continue ›" for a draft, "×3 ›" (its videos, in Takes) once it has
/// takes. A tap anywhere else on the row opens the script's page, whatever its state.
struct ScriptRow: View {
    let script: Script
    let state: ScriptState
    let line: ScriptRowLine
    let takeCount: Int
    /// The world color of the script's topic; nil until it has one.
    let topicColor: Color?
    let showsTrailing: Bool
    let onRecord: () -> Void
    let onTakes: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ThemeRail(color: topicColor ?? Palette.separator)
            VStack(alignment: .leading, spacing: 3) {
                Text(script.displayTitle)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    PlatformDot(color: script.platform.tint, isSmall: true)
                    Text(line.values.joined(separator: " · "))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Palette.inkHint)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(line.values.joined(separator: ", ")))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsTrailing { trailing }
        }
        .padding(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 12))
        .frame(minHeight: 58)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var trailing: some View {
        switch state {
        case .ready:
            RecPill(action: onRecord, accessibilityIdentifier: "row.recordButton")
        case .draft:
            Text("Continue ›")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
                .fixedSize()
                .accessibilityIdentifier("row.continue")
        case .recorded:
            Button(action: onTakes) {
                Text(verbatim: "×\(takeCount) ›")
                    .font(.system(size: 13.5, weight: .semibold))
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
                script: SampleScripts.lampReview, state: .ready, readSeconds: 28, takes: [], hasDraft: { _ in false }
            ),
            takeCount: 0, topicColor: Palette.World.pink, showsTrailing: true, onRecord: {}, onTakes: {}
        )
    }
    .previewEnvironment()
}
#endif
