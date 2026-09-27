//
//  SelectableCard.swift
//  Cue Studio
//

import SwiftUI

/// Tile that shows a yellow outline when selected (fonts, frames, formats, plans).
struct SelectableCard<Content: View>: View {
    var isSelected: Bool
    var radius: CGFloat = 16
    var background: Color = Palette.surface2
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .frame(maxWidth: .infinity)
            .background(isSelected ? Palette.accSoft : background, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Palette.acc : .clear, lineWidth: 1.5))
            .contentShape(shape)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview {
    HStack {
        SelectableCard(isSelected: true) { Text("Aa").padding() }
        SelectableCard(isSelected: false) { Text("Aa").padding() }
    }
    .padding()
    .background(Palette.surface)
}
#endif
