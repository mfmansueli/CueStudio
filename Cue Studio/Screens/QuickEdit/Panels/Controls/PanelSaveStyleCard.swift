//
//  PanelSaveStyleCard.swift
//  Cue Studio
//

import SwiftUI

/// "Save style" among the creator's styles (the last card of Caption style's gallery; first in Text style and Cover): names the
/// look on screen and keeps it for the next videos.
struct PanelSaveStyleCard: View {
    var identifier = "edit.style.saveMine"
    /// The dashed card's size: the gallery's own cards' (Cover's are as tall as the cover's shape).
    var size = CGSize(width: 84, height: 74)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                VStack(spacing: 4) {
                    Image(systemName: "plus").font(.editorGlyph(EditorGlyph.button, weight: .bold))
                    Text("Save style")
                        .font(.system(.caption, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(Palette.accText)
                .padding(.horizontal, 6)
                .frame(width: size.width, height: size.height)
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous)
                        .strokeBorder(Palette.Editor.laneGhostBorder, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                )
                // Lines up with the names under the preset cards.
                Text(verbatim: " ").font(.system(.caption))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
