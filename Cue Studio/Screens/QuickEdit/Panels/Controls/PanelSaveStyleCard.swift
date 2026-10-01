//
//  PanelSaveStyleCard.swift
//  Cue Studio
//

import SwiftUI

/// "Save as my style", first in Text style's presets: keeps the picked text's look for this edit
/// and the next ones.
struct PanelSaveStyleCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                VStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                    Text("Save as my style")
                        .font(.system(.caption, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Palette.acc)
                .padding(.horizontal, 6)
                .frame(width: 84, height: 74)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Palette.laneGhostBorder, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
                // Lines up with the names under the preset cards.
                Text(verbatim: " ").font(.system(.caption))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("edit.style.saveMine")
    }
}
