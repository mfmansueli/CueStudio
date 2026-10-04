//
//  SelectionActionBar.swift
//  Cue Studio
//

import SwiftUI

/// Four rewrites of the words that are selected: ✦ Rewrite · Shorter · Stronger hook · In my voice.
struct SelectionActionBar: View {
    let isWorking: Bool
    let onAction: (SelectionAction) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(SelectionAction.allCases) { action in
                Button { onAction(action) } label: { Text(action.label) }
                    .buttonStyle(.cueAI(.compact, expands: false))
                    .accessibilityIdentifier("page.selection.\(action.rawValue)")
            }
        }
        .padding(6)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .opacity(isWorking ? 0.6 : 1)
        .disabled(isWorking)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.selectionBar")
    }
}
