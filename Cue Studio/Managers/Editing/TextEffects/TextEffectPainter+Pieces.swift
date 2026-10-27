//
//  TextEffectPainter+Pieces.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Layers drawn piece by piece, and the brushes the recipes share: the drop shadow, the band of light, the vertical extent a
/// line's gradient spans.
nonisolated extension TextEffectPainter {
    /// A layer of one image per piece, each `margin` pixels past the piece's ink (for its blur, outline or depth), drawn at
    /// `scale`, its weight added to `bytes`.
    static func layer(
        _ role: TextEffectLayer.Role, _ layout: TextEffectLayout, margin: CGFloat, scale: CGFloat = 1, bytes: inout Int,
        draw: (CGContext, TextEffectLayout.Piece) -> Void
    ) -> TextEffectLayer {
        var weight = 0
        let images = layout.pieces.map { piece -> TextEffectSprite? in
            let area = piece.inkBounds.insetBy(dx: -margin, dy: -margin)
            guard let painted = sprite(area, scale: scale, draw: { draw($0, piece) }) else { return nil }
            weight += painted.bytes
            return painted.sprite
        }
        bytes += weight
        return TextEffectLayer(role: role, images: images)
    }

    /// The shape a piece casts: its outlines, or its line's box around its color glyphs (an emoji has no outline to blur).
    static func silhouette(_ piece: TextEffectLayout.Piece) -> CGPath {
        guard piece.hasColorGlyphs else { return piece.outline }
        let path = CGMutablePath()
        path.addPath(piece.outline)
        let box = piece.bounds.insetBy(dx: piece.bounds.width * 0.08, dy: piece.bounds.height * 0.14)
        path.addRoundedRect(in: box, cornerWidth: box.width * 0.3, cornerHeight: box.height * 0.3)
        return path
    }

    /// The soft shadow under a piece: a wide one and a tight one where it touches.
    static func dropShadow(_ piece: TextEffectLayout.Piece, in context: CGContext, size: CGFloat, strength: Double = 1) {
        let shape = silhouette(piece)
        let black = TextEffectInk.black
        fillBlurred(shape, in: context, color: black.opacity(0.4 * strength), radius: size * 0.07, offset: CGSize(width: 0, height: -size * 0.04))
        fillBlurred(shape, in: context, color: black.opacity(0.3 * strength), radius: size * 0.018, offset: CGSize(width: 0, height: -size * 0.012))
    }

    /// Where a line's gradient runs, bottom to top: from just under the baseline to the top of its capitals.
    static func gradientSpan(_ piece: TextEffectLayout.Piece, in layout: TextEffectLayout) -> (bottom: CGPoint, top: CGPoint) {
        let line = layout.lines[piece.line]
        let cap = line.capHeight > 0 ? line.capHeight : line.ascent * 0.7
        return (CGPoint(x: 0, y: piece.baseline - line.descent * 0.15), CGPoint(x: 0, y: piece.baseline + cap * 1.04))
    }

    /// A band of light `width` wide and `height` tall, upright and centered on the origin: clear at its edges, `color` at
    /// its heart.
    static func band(width: CGFloat, height: CGFloat, color: TextEffectInk, bytes: inout Int) -> TextEffectSprite? {
        let area = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        // Fewer pixels across the height: it is the same along it.
        let drawn = sprite(area, scale: min(1, 256 / max(height, 1))) { context in
            guard let gradient = gradient([
                (0, color.opacity(0)), (0.32, color.opacity(color.alpha * 0.35)), (0.5, color), (0.68, color.opacity(color.alpha * 0.35)),
                (1, color.opacity(0)),
            ]) else { return }
            context.drawLinearGradient(gradient, start: CGPoint(x: area.minX, y: 0), end: CGPoint(x: area.maxX, y: 0), options: [])
        }
        bytes += drawn?.bytes ?? 0
        return drawn?.sprite
    }

    /// A stable number from `text` (the same on every run, unlike Swift's hashing): where the sparkles go.
    static func seed(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
