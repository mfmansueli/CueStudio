//
//  TagPill.swift
//  Cue Studio
//

import SwiftUI

/// Small read-only tag ("Sponsored ad", "v2").
struct TagPill: View {
    var text: String
    var dotColor: Color?

    var body: some View {
        HStack(spacing: 6) {
            if let dotColor { ColorDot(color: dotColor) }
            Text(text)
        }
        .cueFont(.caption, weight: .medium)
        .lineLimit(1)
        // A tag shrinks a little rather than lose letters (owner, 02/11/2026: no label is ever cut).
        .minimumScaleFactor(0.8)
        .foregroundStyle(Palette.inkSoft)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .frame(minHeight: 22)
        .background(Palette.surface2, in: Capsule())
    }
}

#if DEBUG
#Preview {
    TagPill(text: "Sponsored ad").padding().background(Palette.surface)
}
#endif
