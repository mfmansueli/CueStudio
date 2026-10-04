//
//  IdeaCardChip.swift
//  Cue Studio
//

import SwiftUI

/// A small choice on the idea card: "● For TikTok ⌄", "✦ My Cue Voice · Set up", "Need an idea?",
/// "Format ⌄". Violet for what the AI does, neutral for the rest.
struct IdeaCardChip: View {
    enum Style { case neutral, ai }

    let label: String
    var style: Style = .neutral
    var dotColor: Color?
    var systemImage: String?
    var showsChevron = false

    var body: some View {
        HStack(spacing: 5) {
            if let dotColor { ColorDot(color: dotColor, size: 7) }
            if let systemImage { Image(systemName: systemImage).font(.caption.weight(.semibold)) }
            Text(label).lineLimit(1)
            if showsChevron { Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)) }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(style == .ai ? Palette.aiTextStrong : Palette.ink)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(style == .ai ? Palette.aiFill : Palette.overlayFill, in: Capsule())
        .overlay { if style == .ai { Capsule().strokeBorder(Palette.aiBorder, lineWidth: 0.5) } }
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Capsule())
    }
}
