//
//  ScriptSelectionMark.swift
//  Cue Studio
//

import SwiftUI

/// Whether a script is picked while Scripts selects: inside the card's leading end, a ring when it isn't and the yellow circle with a
/// check when it is (22 pt). Drawn by the row, not by the list's edit mode: the system put its circle on the card's edge.
struct ScriptSelectionMark: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22, weight: .regular))
            .symbolRenderingMode(isSelected ? .palette : .monochrome)
            .foregroundStyle(isSelected ? Palette.accInk : Palette.ink2, Palette.acc)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 20) {
        ScriptSelectionMark(isSelected: false)
        ScriptSelectionMark(isSelected: true)
    }
    .padding()
    .background(Palette.surface)
}
#endif
