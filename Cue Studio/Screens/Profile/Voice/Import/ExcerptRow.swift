//
//  ExcerptRow.swift
//  Cue Studio
//

import SwiftUI

/// One excerpt of the creator's writing as it is kept, with a way to take it out: what stays on the iPhone is something they can read and remove,
/// one sentence at a time, not only all at once.
struct ExcerptRow: View {
    let excerpt: VoiceExcerpt
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("“\(excerpt.text)”")
                .font(.subheadline)
                .italic()
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.ink3)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            }
            .accessibilityLabel(Text("Remove"))
            .accessibilityIdentifier("import.excerpt.remove")
        }
        .padding(.leading, 14)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
