//
//  KeepTheirOwnRow.swift
//  Cue Studio
//

import SwiftUI

/// Under the header of the whole video's Adjust, Skin, Filters or Background, when some clips set their own value for what the
/// panel changes: how many, and "Use this on all" to give them the whole video's (only that tool's values; one step, with Undo).
/// Never done by itself.
struct KeepTheirOwnRow: View {
    let count: Int
    let onUseOnAll: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                summary
                Spacer(minLength: 0)
                useOnAll
            }
            VStack(alignment: .leading, spacing: 0) {
                summary
                useOnAll
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.panel.keepTheirOwn")
    }

    private var summary: some View {
        Text("\(count) clips keep their own")
            .font(.system(.footnote))
            .foregroundStyle(Palette.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var useOnAll: some View {
        Button("Use this on all", action: onUseOnAll)
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(Palette.accText)
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityIdentifier("edit.panel.useOnAll")
    }
}
