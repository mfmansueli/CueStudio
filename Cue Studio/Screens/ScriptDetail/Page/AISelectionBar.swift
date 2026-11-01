//
//  AISelectionBar.swift
//  Cue Studio
//

import SwiftUI

/// The AI bar over a selection (v29 · A), a violet pill 40 pt high: ✦ Rewrite · Shorter · Punchier · More me · Cut. While the model
/// works it says "DRAFTING…" with Stop (the page waits meanwhile); once the new words are in the text it offers ✓ Keep · ↺ Undo · ✦ Try
/// again. It doesn't exist without Apple Intelligence.
struct AISelectionBar: View {
    enum Phase: Equatable {
        case choosing
        case writing
        case replaced
    }

    let phase: Phase
    let onAction: (SelectionAction) -> Void
    let onKeep: () -> Void
    let onUndo: () -> Void
    let onRetry: () -> Void
    var onStop: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            switch phase {
            case .choosing:
                ForEach(SelectionAction.allCases) { action in
                    if action == .cut { Divider().frame(height: 18).overlay(Palette.Page.selectionBarRim) }
                    Button { onAction(action) } label: {
                        HStack(spacing: 4) {
                            if action == .rewrite { Image(systemName: "sparkles").cueFont(11, weight: .bold) }
                            Text(action.label)
                        }
                        .cueFont(14, weight: .semibold)
                        .foregroundStyle(action == .cut ? Palette.ink2 : Palette.aiTextStrong)
                        .padding(.horizontal, 11)
                        .frame(minHeight: Metrics.selectionBarHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("page.selection.\(action.rawValue)")
                }
            case .writing:
                HStack(spacing: 8) {
                    ProgressView().tint(Palette.aiText).scaleEffect(0.8)
                    Text("Drafting…")
                        .monoFont(size: 10.5, weight: .bold)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(Palette.aiText)
                }
                .padding(.leading, 16)
                .padding(.trailing, 4)
                .frame(minHeight: Metrics.selectionBarHeight)
                .accessibilityIdentifier("page.selection.writing")
                Divider().frame(height: 18).overlay(Palette.Page.selectionBarRim)
                bar(icon: "xmark", title: "Stop", id: "stop", tint: Palette.aiTextStrong, action: onStop)
            case .replaced:
                bar(icon: "checkmark", title: "Keep", id: "keep", tint: Palette.successText, action: onKeep)
                bar(icon: "arrow.uturn.backward", title: "Undo", id: "undo", tint: Palette.aiTextStrong, action: onUndo)
                bar(icon: "sparkles", title: "Try again", id: "retry", tint: Palette.aiTextStrong, action: onRetry)
            }
        }
        .padding(.horizontal, 4)
        .background(Palette.Page.selectionBar, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.Page.selectionBarRim, lineWidth: 0.5))
        .shadow(color: Palette.Page.selectionBarShadow, radius: 15, y: 12)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.selectionBar")
    }

    private func bar(icon: String, title: LocalizedStringKey, id: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).cueFont(11, weight: .bold)
                Text(title)
            }
            .cueFont(14, weight: .semibold)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(minHeight: Metrics.selectionBarHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("page.selection.\(id)")
    }
}
