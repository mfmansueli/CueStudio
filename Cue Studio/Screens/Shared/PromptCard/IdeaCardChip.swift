//
//  IdeaCardChip.swift
//  Cue Studio
//

import SwiftUI

/// A small choice on the idea card: 30 pt high, 13 pt semibold, its fill, hairline and words in the colour of what it does (the owner,
/// 30/10/2026): the script's settings on dark glass with a white hairline ("TikTok", "Format"), the AI's in violet with its ✦
/// ("✦ Voice 65%"). 28 pt and 12 pt when the card is the bare first-visit one. Where the dock's row is short of room a chip may be its symbol
/// alone (Format's stack, Apple Intelligence's own symbol).
struct IdeaCardChip: View {
    enum Style { case neutral, ai, off }

    let label: String
    var style: Style = .neutral
    var dotColor: Color?
    /// "✦" before the label (the AI's).
    var glyph: String?
    /// A value after the label, quieter than it ("65%").
    var trailingValue: String?
    var showsChevron = false
    /// A small mono tag before the label ("AD": a sponsored ad is picked).
    var isTag: String?
    var isCompact = false
    /// The touch area's height (the dock's row is 36 pt).
    var hitHeight = Metrics.hitTarget
    /// An SF Symbol before the label; with an empty label the chip is the symbol alone.
    var symbol: String?
    /// Each change bounces the symbol (`symbolEffect`), the way the system answers a pick.
    var symbolBounce = 0
    /// Each change lights the ✦: half a turn with a pop, in time with the chip's ring (`UltraChipRing`).
    var glyphLight = 0
    /// The dock's row is short of room: 2 pt less on each side, 1 pt less between what it says.
    var isTight = false
    /// A network's logo in place of its dot (`Platform.logo`).
    var logo: Image?
    /// Each change flips the logo once round, like a coin, landing with a little pop.
    var logoFlip = 0
    /// What the chip says is out, its capsule stays: a chip turning to other words empties first, so the old and the new never cross.
    var hidesContent = false
    /// The capsule takes the width it is given, what it says in the middle (`EqualWidthStack`).
    var stretches = false

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var logoSide = 15.0

    /// The ✦ lighting: how far it has turned and how big it is.
    private struct GlyphLight {
        var turn = 0.0
        var scale = 1.0
    }

    private var height: CGFloat { isCompact ? 28 : 30 }

    var body: some View {
        HStack(spacing: isCompact || isTight ? 5 : 6) {
            if let logo {
                logo
                    .resizable().scaledToFit()
                    .frame(width: logoSide, height: logoSide)
                    // Once round its upright axis, popping as it lands.
                    .keyframeAnimator(initialValue: GlyphLight(), trigger: reduceMotion ? 0 : logoFlip) { logo, light in
                        logo.rotation3DEffect(.degrees(light.turn), axis: (x: 0, y: 1, z: 0)).scaleEffect(light.scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.turn) {
                            LinearKeyframe(0, duration: 0.001)
                            CubicKeyframe(360, duration: 0.55)
                        }
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.35, duration: 0.18, spring: .snappy)
                            SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                        }
                    }
                    .accessibilityHidden(true)
            } else if let dotColor {
                PlatformDot(color: dotColor)
            }
            if let isTag {
                Text(verbatim: isTag)
                    .monoFont(size: 9.5, weight: .bold)
                    .foregroundStyle(Palette.Scripts.adTagInk)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Palette.Scripts.adTagFill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            if let glyph {
                // The ✦ has four points: half a turn ends where it started.
                Text(verbatim: glyph)
                    .foregroundStyle(Palette.aiText)
                    .keyframeAnimator(initialValue: GlyphLight(), trigger: reduceMotion ? 0 : glyphLight) { star, light in
                        star.rotationEffect(.degrees(light.turn)).scaleEffect(light.scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.turn) {
                            LinearKeyframe(0, duration: 0.001)
                            CubicKeyframe(180, duration: 0.5)
                        }
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.5, duration: 0.16, spring: .snappy)
                            SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                        }
                    }
            }
            if let symbol {
                Image(systemName: symbol)
                    .symbolEffect(.bounce, value: reduceMotion ? 0 : symbolBounce)
                    .accessibilityHidden(true)
            }
            // At the biggest text sizes a chip grows and wraps: its words are what says what it does.
            if !label.isEmpty {
                Text(label).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            }
            if let trailingValue {
                Text(verbatim: trailingValue)
                    .cueFont(isCompact ? 12 : 13, weight: .medium)
                    .foregroundStyle(Palette.aiText)
            }
            // The system's mark for a menu, centred on the words (the "⌄" character sat under them).
            if showsChevron {
                Image(systemName: "chevron.up.chevron.down")
                    .cueFont(9, weight: .semibold)
                    .foregroundStyle(style == .ai ? Palette.aiText : Palette.ink2)
                    .accessibilityHidden(true)
            }
        }
        .cueFont(isCompact ? 12 : 13, weight: .semibold)
        .foregroundStyle(foreground)
        .opacity(hidesContent ? 0 : 1)
        .scaleEffect(hidesContent ? 0.8 : 1)
        .frame(maxWidth: stretches ? .infinity : nil)
        .padding(.leading, (dotColor == nil && glyph == nil && logo == nil ? 11 : 9) - (isTight ? 2 : 0))
        .padding(.trailing, isTight ? 9 : 11)
        .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
        .frame(minHeight: height)
        .background(background, in: Capsule())
        .overlay { if !isCompact { Capsule().strokeBorder(stroke, lineWidth: 1) } }
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

    private var stroke: Color {
        style == .ai ? Palette.Scripts.heroChipAIStroke : Palette.Scripts.heroChipStroke
    }

    private var background: Color {
        switch style {
        case .neutral: isCompact ? Palette.bg.opacity(0.45) : Palette.Scripts.heroChipGlass
        case .ai: isCompact ? Color(hex: 0x9D8CFF, opacity: 0.26) : Palette.Scripts.heroChipAI
        case .off: Palette.fill
        }
    }
}
