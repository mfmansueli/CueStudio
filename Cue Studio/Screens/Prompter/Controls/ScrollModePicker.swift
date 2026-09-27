//
//  ScrollModePicker.swift
//  Cue Studio
//

import SwiftUI

/// "Voice Following | Steady" at the top of the prompter toolbar.
struct ScrollModePicker: View {
    let selection: ScrollMode
    let onSelect: (ScrollMode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            segment(.voice, systemImage: "mic")
            segment(.steady, systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        .padding(2)
        .frame(height: 36)
        .background(Palette.overlayFill.opacity(0.8), in: Capsule())
        .frame(minHeight: Metrics.hitTarget)
    }

    private func segment(_ mode: ScrollMode, systemImage: String) -> some View {
        let isOn = selection == mode
        return Button { onSelect(mode) } label: {
            Label(mode.label, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? Palette.ink : Palette.ink.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isOn ? Palette.neutralAction : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("prompter.scrollMode.\(mode.rawValue)")
        .animation(.smooth(duration: 0.2), value: isOn)
    }
}

#if DEBUG
#Preview {
    ScrollModePicker(selection: .voice, onSelect: { _ in })
        .padding()
        .background(Color.black)
}
#endif
