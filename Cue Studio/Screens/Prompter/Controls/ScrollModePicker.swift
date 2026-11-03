//
//  ScrollModePicker.swift
//  Cue Studio
//

import SwiftUI

/// "Voice | Steady" at the top of the prompter's bars, each with its symbol beside the word. It is drawn by Cue because the system's segmented
/// control takes a word or a symbol for a segment, not both; it looks like that control (a dark track and a lighter segment that glides to
/// the one chosen), is as tall as the round buttons beside it and tells VoiceOver which one is selected.
///
/// The words are never cut, in any language (owner, 02/11/2026: "Const…" in Portuguese): the segments share the track fairly
/// (`FairShareLayout`: equal halves when both words fit, else each its own width), and when the words and symbols don't fit side by side
/// the symbols step aside; past that, the words shrink a little rather than lose letters.
struct ScrollModePicker: View {
    let selection: ScrollMode
    let onSelect: (ScrollMode) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let modes: [ScrollMode] = [.voice, .steady]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            segments(showsSymbols: true)
            segments(showsSymbols: false)
        }
        .padding(3)
        .frame(height: Metrics.hitTarget)
        .background(Palette.overlayFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("prompter.scrollMode")
    }

    /// The thumb under the chosen segment, then the segments.
    private func segments(showsSymbols: Bool) -> some View {
        FairShareLayout(underlay: Self.modes.firstIndex(of: selection) ?? 0) {
            Capsule()
                .fill(Palette.segmentThumb)
                .accessibilityHidden(true)
            ForEach(Self.modes) { mode in
                option(mode, showsSymbol: showsSymbols)
            }
        }
    }

    private func option(_ mode: ScrollMode, showsSymbol: Bool) -> some View {
        let isSelected = mode == selection
        return Button { onSelect(mode) } label: {
            HStack(spacing: 6) {
                if showsSymbol {
                    Image(systemName: mode.symbolName)
                        .cueFont(14, weight: .semibold)
                }
                Text(mode.shortLabel)
                    .cueFont(15, weight: .semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? Palette.ink : Palette.ink2)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(mode.shortLabel))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview {
    VStack {
        ScrollModePicker(selection: .voice, onSelect: { _ in })
        ScrollModePicker(selection: .steady, onSelect: { _ in })
        ScrollModePicker(selection: .steady, onSelect: { _ in }).frame(width: 150)
    }
    .padding()
    .background(Color.black)
}
#endif
