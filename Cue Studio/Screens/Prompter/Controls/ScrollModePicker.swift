//
//  ScrollModePicker.swift
//  Cue Studio
//

import SwiftUI

/// "Voice | Steady" at the top of the prompter's bars, each with its symbol beside the word. It is drawn by Cue because the system's segmented
/// control takes a word or a symbol for a segment, not both; it looks like that control (a dark track and a lighter segment that glides to
/// the one chosen), is as tall as the round buttons beside it and tells VoiceOver which one is selected.
struct ScrollModePicker: View {
    let selection: ScrollMode
    let onSelect: (ScrollMode) -> Void

    @Namespace private var segment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach([ScrollMode.voice, .steady]) { mode in
                option(mode)
            }
        }
        .padding(3)
        .frame(height: Metrics.hitTarget)
        .background(Palette.overlayFill, in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("prompter.scrollMode")
    }

    private func option(_ mode: ScrollMode) -> some View {
        let isSelected = mode == selection
        return Button { onSelect(mode) } label: {
            HStack(spacing: 6) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                Text(mode.shortLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Palette.ink : Palette.ink2)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Palette.segmentThumb)
                        .matchedGeometryEffect(id: "segment", in: segment)
                }
            }
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
    }
    .padding()
    .background(Color.black)
}
#endif
