//
//  ScriptRowBackground.swift
//  Cue Studio
//

import SwiftUI

/// One row's slice of the group card (`surface`, 20 pt corners, the faint violet edge, the group's shadow) with the hairline between rows.
struct ScriptRowBackground: View {
    let position: CardRowPosition

    var body: some View {
        let shape = UnevenRoundedRectangle(cornerRadii: position.cornerRadii(20), style: .continuous)
        shape.fill(Palette.surface)
            .overlay(shape.strokeBorder(Palette.glassBorder.opacity(0.7), lineWidth: 0.5))
            .overlay(alignment: .top) {
                if position == .middle || position == .last {
                    Rectangle().fill(Palette.glassBorder.opacity(0.55)).frame(height: 0.5)
                }
            }
            .cardDepth(shape, openEdges: position.openEdges, edge: nil)
    }
}
