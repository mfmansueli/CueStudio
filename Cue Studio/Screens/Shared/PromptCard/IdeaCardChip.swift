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
    /// A chip that sits inside a bigger capsule (the voice chip with its switch) draws no capsule of its own.
    var fillsCapsule = true

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 5) {
            if let dotColor { ColorDot(color: dotColor, size: 7) }
            if let systemImage { Image(systemName: systemImage).font(.caption.weight(.semibold)) }
            // At the biggest text sizes a chip grows and wraps: its words are what says what it does.
            Text(label).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            if showsChevron { Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)) }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(style == .ai ? Palette.aiTextStrong : Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
        .frame(minHeight: 32)
        .background { if fillsCapsule { Capsule().fill(style == .ai ? Palette.aiFill : Palette.overlayFill) } }
        .overlay { if style == .ai && fillsCapsule { Capsule().strokeBorder(Palette.aiBorder, lineWidth: 0.5) } }
        .frame(minHeight: Metrics.hitTarget)
        .contentShape(Capsule())
    }
}
