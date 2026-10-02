//
//  FilterChip.swift
//  Cue Studio
//

import SwiftUI

/// Selectable capsule used for filters and single-choice rows. Use as a `Button` label.
struct FilterChip: View {
    var label: String
    var isSelected: Bool
    var dotColor: Color?
    var systemImage: String?
    var height: CGFloat = Metrics.chipHeight

    var body: some View {
        HStack(spacing: 7) {
            if let dotColor { ColorDot(color: dotColor) }
            if let systemImage { Image(systemName: systemImage).font(.footnote.weight(.semibold)) }
            Text(label)
        }
        .font(.subheadline.weight(isSelected ? .semibold : .medium))
        .lineLimit(1)
        .padding(.horizontal, 14)
        .frame(height: height)
        .foregroundStyle(isSelected ? Palette.bg : Palette.ink)
        .background(isSelected ? Palette.ink : Palette.fill, in: Capsule())
        .contentShape(Capsule())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#Preview {
    HStack {
        FilterChip(label: "All", isSelected: true)
        FilterChip(label: "TikTok", isSelected: false, dotColor: Palette.platformTikTok)
    }
    .padding()
    .background(Palette.bg)
}
#endif
