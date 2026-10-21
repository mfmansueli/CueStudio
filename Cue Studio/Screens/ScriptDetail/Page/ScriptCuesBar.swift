//
//  ScriptCuesBar.swift
//  Cue Studio
//

import SwiftUI

/// The cues over the keyboard (v29 · 4.2), riding on it as one full-width Liquid Glass bar: Undo and Redo for the text (when the page
/// hands in the editor's `undo`) and a divider, then the board's four cues (pause, smile, emphasis, look at camera) and the creator's
/// own, as tags that scroll inside the bar (clipped, fading at its edges), a divider, and a "+" fixed at the end for a new one, so no
/// cue ever passes under it. A tap puts the cue where the caret is; holding one of the creator's takes it off the bar.
struct ScriptCuesBar: View {
    let cues: [String]
    /// The creator's own, the ones that can leave the bar.
    let customCues: [String]
    let onCue: (String) -> Void
    let onAdd: () -> Void
    let onRemove: (String) -> Void
    /// The editor's history: Undo and Redo lead the bar while there is one, each lit only when it has something to do.
    var undo: ScriptEditorUndo?

    private static let height: CGFloat = 52
    /// The round Undo and Redo: a 34 pt circle (the cue tags' height) in a 44 pt wide slot.
    private static let historyButton: CGFloat = 34
    /// How far the tags fade out before the bar's ends.
    private static let fade: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            if let undo {
                history(undo)
                divider
            }
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(cues, id: \.self) { cue in
                        chip(cue)
                    }
                }
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.hidden)
            .mask(edgeFade)
            divider
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: Self.height, height: Self.height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("New cue"))
            .accessibilityIdentifier("page.addCueButton")
        }
        .frame(height: Self.height)
        .glassEffect(.regular.tint(Palette.surface), in: Capsule())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.cuesBar")
    }

    private var divider: some View {
        Rectangle()
            .fill(Palette.separator)
            .frame(width: 1, height: 24)
            .accessibilityHidden(true)
    }

    private func history(_ undo: ScriptEditorUndo) -> some View {
        HStack(spacing: 0) {
            historyButton("arrow.uturn.backward", label: "Undo", id: "cuesBar.undo", isEnabled: undo.canUndo) { undo.undo() }
            historyButton("arrow.uturn.forward", label: "Redo", id: "cuesBar.redo", isEnabled: undo.canRedo) { undo.redo() }
        }
        .padding(.leading, 4)
        .padding(.trailing, 2)
    }

    /// A round button over the glass; dimmed to `ink3` when there is nothing to take back (an inactive control, WCAG 1.4.11 asks
    /// nothing of it).
    private func historyButton(
        _ symbol: String,
        label: LocalizedStringKey,
        id: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isEnabled ? Palette.ink : Palette.ink3)
                .frame(width: Self.historyButton, height: Self.historyButton)
                .background(Palette.fill, in: Circle())
                .frame(width: Metrics.hitTarget, height: Self.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(id)
    }

    /// Opaque in the middle, clear at both ends: a tag scrolling out fades before the divider instead of being cut by it.
    private var edgeFade: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: Self.fade)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: Self.fade)
        }
    }

    private func chip(_ cue: String) -> some View {
        Button { onCue(cue) } label: {
            Text(verbatim: cue)
                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.accText)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(Palette.accSoft, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if customCues.contains(cue) {
                Button("Remove from bar", systemImage: "minus.circle", role: .destructive) { onRemove(cue) }
            }
        }
        .accessibilityLabel(Text("Cue \(cue)"))
        .accessibilityIdentifier("page.cue.\(cue)")
    }
}
