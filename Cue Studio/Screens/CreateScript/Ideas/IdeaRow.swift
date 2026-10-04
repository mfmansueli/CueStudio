//
//  IdeaRow.swift
//  Cue Studio
//

import SwiftUI

/// An idea: its title in serif, "LIST · ~1 MIN · LIFESTYLE" in mono, and a yellow ↑ that writes it.
/// Tapping the row takes the idea to the card to edit first.
struct IdeaRow: View {
    let idea: ThemeIdea
    let canWrite: Bool
    let onEdit: () -> Void
    let onWrite: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(idea.title)
                        .font(.system(.body, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(idea.meta)
                        .font(CueStudioFont.hud)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Edit it on the card first"))
            Button(action: onWrite) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.accInk)
                    .frame(width: 34, height: 34)
                    .background(Palette.acc.opacity(canWrite ? 1 : 0.35), in: Circle())
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canWrite)
            .accessibilityLabel(Text("Write this script"))
            .accessibilityIdentifier("ideas.write.\(idea.id)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ideas.row.\(idea.id)")
    }
}
