//
//  MediaModeCards.swift
//  Cue Studio
//

import SwiftUI

/// Where a pick goes, as four cards with their drawing: at the same time as the video (Overlay: Split screen, Window, Full
/// screen) or in the sequence, adding time. The groups are named, so "on top" and "in the sequence" are never confused.
struct MediaModeCards: View {
    @Binding var selection: MediaInsertMode

    /// The drawing in each card: 16 × 28 pt (was 22 × 38).
    static let diagramSize = CGSize(width: 16, height: 28)

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            group(String(localized: "Overlay · at the same time"), modes: MediaInsertMode.overlays)
            group(String(localized: "Sequence"), modes: [.sequence])
                .frame(width: 84)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.mediaMode")
    }

    private func group(_ title: String, modes: [MediaInsertMode]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 8) {
                ForEach(modes) { mode in card(mode) }
            }
        }
    }

    private func card(_ mode: MediaInsertMode) -> some View {
        let isOn = mode == selection
        return Button {
            guard !isOn else { return }
            Haptics.selection()
            selection = mode
        } label: {
            VStack(spacing: 4) {
                // Smaller than before (owner, canvas 2 F14): the drawing stays, the gallery gets the room.
                MediaLayoutDiagram(shape: .mode(mode), isOn: isOn, size: Self.diagramSize)
                // Two lines broken between words, never inside one (owner, 02/11/2026: no label is ever cut).
                WholeWordsLabel(text: mode.label, minimumScale: 0.8)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink)
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget + 18)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
            .editorCard(isOn ? .picked : .plain)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(mode.label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.mediaMode.\(mode.rawValue)")
    }
}
