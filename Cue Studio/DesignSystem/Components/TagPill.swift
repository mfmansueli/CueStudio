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
        .font(.caption.weight(.medium))
        .lineLimit(1)
        .foregroundStyle(Palette.ink.opacity(0.8))
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Palette.surface2, in: Capsule())
    }
}

#if DEBUG
#Preview {
    TagPill(text: "Sponsored ad").padding().background(Palette.surface)
}
#endif
