//
//  ScriptDraftBar.swift
//  Cue Studio
//

import SwiftUI

/// The bar under the Draft: "✦ Shape", "¶ Cue break", Aa, and what the platform wants.
struct ScriptDraftBar: View {
    let platform: Platform
    let idealRange: ClosedRange<TimeInterval>
    let onShape: () -> Void
    let onCueBreak: () -> Void
    let onTextSize: () -> Void

    var body: some View {
        // The three buttons are the bar; the hint is dropped when they leave no room for it.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                buttons
                Spacer(minLength: 0)
                hint
            }
            HStack(spacing: 8) {
                buttons
                Spacer(minLength: 0)
            }
        }
        // Like the top bar, chrome that stops growing at a large text size.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.surface)
        .overlay(alignment: .top) { Rectangle().fill(Palette.separator).frame(height: 0.5) }
    }

    @ViewBuilder
    private var buttons: some View {
        Button(action: onShape) { Text("✦ Shape") }
            .buttonStyle(.cueAI(.medium, expands: false))
            .fixedSize()
            .accessibilityIdentifier("page.shapeButton")
        Button(action: onCueBreak) { Text("¶ Cue break") }
            .buttonStyle(.cueSecondary(.medium, expands: false))
            .fixedSize()
            .accessibilityIdentifier("page.cueBreakButton")
        Button(action: onTextSize) { Text("Aa") }
            .buttonStyle(.cueSecondary(.medium, expands: false))
            .fixedSize()
            .accessibilityLabel(Text("Text size"))
            .accessibilityIdentifier("page.textSizeButton")
    }

    private var hint: some View {
        Text("\(platform.label) · ideal \(DurationText.clock(idealRange.lowerBound))–\(DurationText.clock(idealRange.upperBound))")
            .font(.caption)
            .foregroundStyle(Palette.ink2)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .layoutPriority(-1)
            .accessibilityIdentifier("page.platformHint")
    }
}
