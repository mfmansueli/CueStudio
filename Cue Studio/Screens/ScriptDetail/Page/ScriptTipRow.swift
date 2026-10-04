//
//  ScriptTipRow.swift
//  Cue Studio
//

import SwiftUI

/// Advice under the words: "Hook is 5 s — under 3 s holds more viewers", the fix and ✕. Plain advice, not the AI's: neutral.
struct ScriptTipRow: View {
    let tip: ScriptShape.Tip
    let onFix: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Group {
            if typeSize.isAccessibilitySize {
                // With the biggest text the message needs the whole width: Fix and ✕ go on a line under it.
                VStack(alignment: .leading, spacing: 0) {
                    messageLine
                    HStack(spacing: 8) {
                        fixButton
                        Spacer(minLength: 0)
                        dismissButton
                    }
                }
            } else {
                HStack(spacing: 8) {
                    messageLine
                    fixButton
                    dismissButton
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(Palette.ink2)
        .padding(.leading, 12)
        .padding(.trailing, 2)
        .background(Palette.surface, in: shape)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.tip.\(tip.id)")
    }

    private var messageLine: some View {
        message
            .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
    }

    private var fixButton: some View {
        Button(action: onFix) {
            fixLabel
                .font(.footnote.weight(.bold))
                .foregroundStyle(Palette.accText)
                .padding(.horizontal, 4)
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("page.tip.fix")
    }

    private var dismissButton: some View {
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
