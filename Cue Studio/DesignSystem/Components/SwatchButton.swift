//
//  SwatchButton.swift
//  Cue Studio
//

import SwiftUI

/// Round color swatch with a selection ring.
struct SwatchButton: View {
    var color: Color
    var isSelected: Bool
    var accessibilityName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                .frame(width: 26, height: 26)
                .padding(3)
                .overlay(Circle().strokeBorder(isSelected ? Color.white : .clear, lineWidth: 2))
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview {
    HStack {
        SwatchButton(color: .white, isSelected: true, accessibilityName: "White") {}
        SwatchButton(color: Palette.acc, isSelected: false, accessibilityName: "Yellow") {}
    }
    .padding()
    .background(Palette.surface2)
}
#endif
