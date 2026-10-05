//
//  ScrollModePicker.swift
//  Cue Studio
//

import SwiftUI

/// "Voice | Steady" at the top of the prompter toolbar: a 44 pt track with a 3 pt inset, the
/// chosen segment in gray (`segmentOn`). Voice carries a little waveform, Steady a scroll mark.
struct ScrollModePicker: View {
    let selection: ScrollMode
    /// False when Voice Following can't listen (the practice without the microphone): its segment is dimmed and inert.
    var isVoiceAvailable = true
    let onSelect: (ScrollMode) -> Void

    var body: some View {
        HStack(spacing: 3) {
            segment(.voice)
            segment(.steady)
        }
        .padding(3)
        .frame(height: Metrics.hitTarget)
        .background(Palette.overlayFill.opacity(0.8), in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.glassBorder, lineWidth: 0.5))
    }

    private func segment(_ mode: ScrollMode) -> some View {
        let isOn = selection == mode
        let isAvailable = mode != .voice || isVoiceAvailable
        return Button { onSelect(mode) } label: {
            HStack(spacing: 6) {
                switch mode {
                case .voice: WaveGlyph(tint: isOn ? Palette.ink : Palette.ink.opacity(0.7))
                case .steady:
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                        .font(.footnote.weight(.semibold))
                }
                Text(mode.shortLabel)
                    .lineLimit(1)
            }
            .font(.system(size: 13.5, weight: isOn ? .semibold : .medium))
            .foregroundStyle(isOn ? Palette.ink : Palette.ink.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isOn ? Palette.segmentOn : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.4)
        .accessibilityLabel(Text(mode.label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("prompter.scrollMode.\(mode.rawValue)")
        .animation(.smooth(duration: 0.2), value: isOn)
    }

    /// Five small bars, a still waveform.
    private struct WaveGlyph: View {
        let tint: Color

        var body: some View {
            HStack(spacing: 1.5) {
                ForEach([6.0, 12, 14, 9, 12], id: \.self) { height in
                    Capsule().fill(tint).frame(width: 2.5, height: height)
                }
            }
            .frame(height: 14)
            .accessibilityHidden(true)
        }
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
