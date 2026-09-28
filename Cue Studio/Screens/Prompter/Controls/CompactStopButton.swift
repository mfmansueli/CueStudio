//
//  CompactStopButton.swift
//  Cue Studio
//

import SwiftUI

/// The one control left on screen while recording with the controls hidden.
struct CompactStopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Palette.record)
                .frame(width: 24, height: 24)
                .frame(width: 64, height: 64)
                .background(Palette.stopButtonFill, in: Circle())
                .overlay(Circle().strokeBorder(Palette.stopButtonRing, lineWidth: 3))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Stop recording"))
        .accessibilityIdentifier("prompter.compactStopButton")
    }
}

#if DEBUG
#Preview {
    CompactStopButton {}
        .padding()
        .background(Color.gray)
}
#endif
