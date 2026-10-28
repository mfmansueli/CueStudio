//
//  TextOverlayRenderer+Effect.swift
//  Cue Studio
//

import UIKit

/// A text with an effect, as the effects' code asks for it (`TextEffectRequest`): its words in its font, weight, size, letter
/// spacing and alignment, its colors, its lines as long as its block or the frame allows, cut into letters, or into words where
/// letters join or stack (Arabic, the Indic scripts, Thai), for Headline, and for a long text.
nonisolated extension TextOverlayRenderer {
    /// Past this many letters an effect moves words: as many letter images would weigh more than they show.
    static let mostEffectLetters = 40

    /// What `text`'s effect is drawn from on a frame `frameWidth` wide; nil for a text without one (or a graphic, or empty).
    static func effectRequest(for text: TextOverlay, frameWidth: CGFloat, widthFraction: CGFloat) -> TextEffectRequest? {
        guard let effect = text.effect, text.graphic == nil, !text.isEmpty, frameWidth > 0 else { return nil }
        let scale = CGFloat(text.block?.scale(at: text.size) ?? 1)
        let unit = frameWidth / referenceWidth
        let pointSize = CGFloat(text.size) * unit
        let words = text.displayText
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(for: text, size: pointSize), .paragraphStyle: paragraphStyle(for: text),
        ]
        let spaced = TextShaping.allowsLetterSpacing(in: words)
        if abs(text.tracking) > 0.000_1, spaced { attributes[.kern] = CGFloat(text.tracking) * pointSize }
        let padding = effectPadding(for: effect.kind, unit: unit * scale, pointSize: pointSize)
        let maxWidth = lineLength(for: text, frameWidth: frameWidth, widthFraction: widthFraction) ?? (frameWidth * widthFraction - padding.width * 2)
        let letters = words.filter { !$0.isWhitespace }.count
        let byWords = effect.kind.movesWords || !spaced || letters > mostEffectLetters
        // Everything the painting depends on: its motion and duration only move it, so they aren't part of it.
        var key = Hasher()
        key.combine(words)
        key.combine(text.font)
        key.combine(text.weight)
        key.combine(text.size)
        key.combine(text.tracking)
        key.combine(text.alignment)
        key.combine(text.color)
        key.combine(text.block)
        key.combine(effect.kind)
        key.combine(effect.accent)
        key.combine(effect.tone)
        key.combine(effect.intensity)
        key.combine(effect.direction)
        key.combine(widthFraction)
        return TextEffectRequest(
            string: NSAttributedString(string: words, attributes: attributes), effect: effect, color: ink(text.color),
            accent: ink(effect.accent), pointSize: pointSize, maxWidth: max(1, maxWidth), padding: padding, byWords: byWords,
            key: "\(key.finalize())-\(Int((frameWidth * 4).rounded()))"
        )
    }

    /// Between an effect's box and its lines: the usual padding, and for Headline the band's own reach past the words.
    static func effectPadding(for kind: TextEffectKind, unit: CGFloat, pointSize: CGFloat) -> CGSize {
        let base = CGSize(width: 8 * unit, height: 6 * unit)
        guard kind == .headline else { return base }
        return CGSize(width: max(base.width, pointSize * 0.26), height: max(base.height, pointSize * 0.16))
    }

    static func ink(_ color: OverlayColor) -> TextEffectInk {
        let parts = color.components
        return TextEffectInk(red: parts.red, green: parts.green, blue: parts.blue)
    }
}
