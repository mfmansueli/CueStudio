//
//  ScriptCuesBar.swift
//  Cue Studio
//

import SwiftUI

/// The cues over the keyboard (v29 · 4.2), riding on it as one full-width Liquid Glass bar: the board's four (pause, smile,
/// emphasis, look at camera), then the creator's own, as tags that scroll inside the bar (clipped, fading at its edges), a divider,
/// and a "+" fixed at the end for a new one, so no cue ever passes under it. A tap puts the cue where the caret is; holding one of
/// the creator's takes it off the bar.
struct ScriptCuesBar: View {
    let cues: [String]
    /// The creator's own, the ones that can leave the bar.
    let customCues: [String]
    let onCue: (String) -> Void
    let onAdd: () -> Void
    let onRemove: (String) -> Void

    private static let height: CGFloat = 52
    /// How far the tags fade out before the bar's ends.
    private static let fade: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
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
            Rectangle()
                .fill(Palette.separator)
                .frame(width: 1, height: 24)
                .accessibilityHidden(true)
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
