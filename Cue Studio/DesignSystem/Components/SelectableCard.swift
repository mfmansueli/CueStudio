//
//  SelectableCard.swift
//  Cue Studio
//

import SwiftUI

/// Tile that shows a 2 pt yellow ring over a 12% yellow tint when selected (fonts, frames, formats, plans).
struct SelectableCard<Content: View>: View {
    var isSelected: Bool
    var radius: CGFloat = 16
    var background: Color = Palette.surface2
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .frame(maxWidth: .infinity)
            .background(isSelected ? Palette.Editor.accTile : background, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Palette.acc : .clear, lineWidth: 2))
            .cardDepth(shape, edge: isSelected ? nil : Palette.Depth.edge)
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
