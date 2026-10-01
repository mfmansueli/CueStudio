//
//  PanelNote.swift
//  Cue Studio
//

import SwiftUI

/// A short note in a panel (only the ones the design has: no fixed help text under controls).
struct PanelNote: View {
    let text: String
    var tint: Color = Palette.ink2

    var body: some View {
        Text(text)
            .font(.system(.footnote))
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}
