//
//  ScriptRow.swift
//  Cue Studio
//

import SwiftUI

/// A script on the Scripts list (v29): the topic's bar, the title, a mono line ("● TIKTOK · 0:47 · 4 CUES") and the one
/// way forward for its state: "● REC" when it is ready, "Continue ›" for a draft, "×3 ›" once it has takes.
struct ScriptRow: View {
    let script: Script
    let state: ScriptState
    let line: ScriptRowLine
    let takeCount: Int
    /// The world color of the script's topic; nil until it has one.
    let topicColor: Color?
    let showsTrailing: Bool
    let onRecord: () -> Void

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
                .foregroundStyle(Palette.ink.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
                .accessibilityIdentifier("row.continue")
        case .recorded:
            Text(verbatim: "×\(takeCount) ›")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Palette.ink.opacity(0.75))
                .lineLimit(1)
                .fixedSize()
                .accessibilityIdentifier("row.takes")
        }
    }
}

/// One row's slice of the group card (`surface`, 20 pt corners, the faint violet edge, the group's shadow) with the hairline between rows.
struct ScriptRowBackground: View {
    let position: CardRowPosition

    var body: some View {
        let shape = UnevenRoundedRectangle(cornerRadii: position.cornerRadii(20), style: .continuous)
        shape.fill(Palette.surface)
            .overlay(shape.strokeBorder(Palette.glassBorder.opacity(0.7), lineWidth: 0.5))
            .overlay(alignment: .top) {
                if position == .middle || position == .last {
                    Rectangle().fill(Palette.glassBorder.opacity(0.55)).frame(height: 0.5)
                }
            }
            .cardDepth(shape, openEdges: position.openEdges, edge: nil)
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
            takeCount: 0, topicColor: Palette.World.pink, showsTrailing: true, onRecord: {}
        )
    }
    .previewEnvironment()
}
#endif
