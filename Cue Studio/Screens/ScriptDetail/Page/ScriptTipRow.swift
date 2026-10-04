//
//  ScriptTipRow.swift
//  Cue Studio
//

import SwiftUI

/// Advice under a section, in violet: "✦ Hook is 5 s — under 3 s holds more viewers", the fix and ✕.
struct ScriptTipRow: View {
    let tip: ScriptShape.Tip
    let onFix: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 8) {
            Text("✦").foregroundStyle(Palette.aiText)
            message
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onFix) {
                fixLabel
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 4)
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("page.tip.fix")
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 32, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Dismiss"))
            .accessibilityIdentifier("page.tip.dismiss")
        }
        .font(.footnote)
        .foregroundStyle(Palette.aiTextStrong)
        .padding(.leading, 10)
        .padding(.trailing, 2)
        .background(Palette.aiFill, in: shape)
        .overlay(shape.strokeBorder(Palette.aiBorder, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.tip.\(tip.id)")
    }

    @ViewBuilder
    private var message: some View {
        switch tip {
        case .longHook(let seconds): Text("Hook is \(seconds) s — under 3 s holds more viewers")
        case .longSentence: Text("Long sentence — split for reading")
        }
    }

    @ViewBuilder
    private var fixLabel: some View {
        switch tip {
        case .longHook: Text("Fix")
        case .longSentence: Text("Split")
        }
    }
}
