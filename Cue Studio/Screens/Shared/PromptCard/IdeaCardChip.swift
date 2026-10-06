//
//  IdeaCardChip.swift
//  Cue Studio
//

import SwiftUI

/// A small choice on the idea card, as the board draws it: 30 pt high, 13 pt semibold on a dark glass capsule ("● For TikTok",
/// "Format ⌄"), and the AI's chip in violet with its ✦ ("✦ Voice 65%"). 28 pt and 12 pt when the card is the bare first-visit one.
struct IdeaCardChip: View {
    enum Style { case neutral, ai, off }

    let label: String
    var style: Style = .neutral
    var dotColor: Color?
    /// "✦" before the label (the AI's).
    var glyph: String?
    /// A small mono value after the label ("65%").
    var trailingMono: String?
    var showsChevron = false
    /// A small mono tag before the label ("AD": a sponsored ad is picked).
    var isTag: String?
    var isCompact = false
    /// The touch area's height (the dock's row is 36 pt).
    var hitHeight = Metrics.hitTarget

    @Environment(\.dynamicTypeSize) private var typeSize

    private var height: CGFloat { isCompact ? 28 : 30 }

    var body: some View {
        HStack(spacing: isCompact ? 5 : 6) {
            if let dotColor { PlatformDot(color: dotColor) }
            if let isTag {
                Text(verbatim: isTag)
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.adTagInk)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Palette.adTagFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            if let glyph { Text(verbatim: glyph).foregroundStyle(Palette.aiText) }
            // At the biggest text sizes a chip grows and wraps: its words are what says what it does.
            Text(label).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            if let trailingMono {
                Text(verbatim: trailingMono)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Palette.aiText)
            }
            if showsChevron { Text(verbatim: "⌄").foregroundStyle(Palette.inkHint) }
        }
        .font(.system(size: isCompact ? 12 : 13, weight: .semibold))
        .foregroundStyle(foreground)
        .padding(.leading, dotColor == nil && glyph == nil ? 11 : 9)
        .padding(.trailing, 11)
        .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
        .frame(minHeight: height)
        .background(background, in: Capsule())
        .overlay { if style == .ai && !isCompact { Capsule().strokeBorder(Palette.heroChipAIStroke, lineWidth: 0.5) } }
        .frame(minHeight: hitHeight)
        .contentShape(Capsule())
    }

    private var foreground: Color {
        switch style {
        case .neutral: Palette.ink
        case .ai: Palette.aiTextStrong
        case .off: Palette.ink.opacity(0.7)
        }
    }

    private var background: Color {
        switch style {
        case .neutral: isCompact ? Palette.bg.opacity(0.45) : Palette.heroChip
        case .ai: isCompact ? Color(hex: 0x9D8CFF, opacity: 0.26) : Palette.heroChipAI
        case .off: Palette.fill
        }
    }
}
