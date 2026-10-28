//
//  TextEffectPainter+Wave.swift
//  Cue Studio
//

import CoreGraphics

/// Wave and Sheen: letters in the text's color, lit a touch at the top and shaded at the bottom, over a soft shadow. Wave's
/// is all in its motion (`TextEffectChoreography`); Sheen adds a fine edge for bright pictures and a band of light that
/// crosses it once.
nonisolated extension TextEffectPainter {
    static func wave(_ layout: TextEffectLayout, _ request: TextEffectRequest) -> TextEffectArtwork {
        let size = request.pointSize
        let color = request.color
        var artwork = TextEffectArtwork()
        artwork.layers.append(layer(.shadow, layout, margin: size * 0.24, bytes: &artwork.bytes) { context, piece in
            dropShadow(piece, in: context, size: size, strength: 1.1)
        })
        artwork.layers.append(layer(.face, layout, margin: size * 0.02, bytes: &artwork.bytes) { context, piece in
            let span = gradientSpan(piece, in: layout)
            fillGradient(
                piece.outline, in: context, stops: [(0, color.darkened(0.1)), (0.55, color), (1, color.lightened(0.16))],
                from: span.bottom, to: span.top
            )
            innerShadow(
                piece.outline, in: context, color: TextEffectInk.black.opacity(0.16), radius: size * 0.03,
                offset: CGSize(width: 0, height: size * 0.022)
            )
            drawColorGlyphs(piece, in: context)
        })
        return artwork
    }

    static func sheen(_ layout: TextEffectLayout, _ request: TextEffectRequest) -> TextEffectArtwork {
        let size = request.pointSize
        let color = request.color
        let dark = color.luminance < 0.25
        var artwork = TextEffectArtwork()
        artwork.layers.append(layer(.shadow, layout, margin: size * 0.24, bytes: &artwork.bytes) { context, piece in
            dropShadow(piece, in: context, size: size, strength: dark ? 0.35 : 0.95)
        })
        // A fine edge, so a pale finish keeps its letters over a bright picture (a light one around dark letters).
        let edge = dark ? TextEffectInk.white.opacity(0.45) : TextEffectInk.black.opacity(0.28)
        artwork.layers.append(layer(.body, layout, margin: size * 0.04, bytes: &artwork.bytes) { context, piece in
            strokeOutside(piece.outline, in: context, color: edge, width: max(1, size * 0.016))
        })
        artwork.layers.append(layer(.face, layout, margin: size * 0.02, bytes: &artwork.bytes) { context, piece in
            let span = gradientSpan(piece, in: layout)
            fillGradient(
                piece.outline, in: context,
                stops: [(0, color.darkened(0.16)), (0.45, color.darkened(0.04)), (0.62, color), (1, color.lightened(0.22))],
                from: span.bottom, to: span.top
            )
            innerShadow(
                piece.outline, in: context, color: TextEffectInk.white.opacity(0.4), radius: size * 0.014,
                offset: CGSize(width: 0, height: -size * 0.014)
            )
            drawColorGlyphs(piece, in: context)
        })
        let bounds = layout.textBounds
        artwork.sweep = band(
            width: size * 0.42, height: (bounds.height + size) * 1.6,
            color: TextEffectInk.white.opacity(0.5 + 0.45 * request.effect.intensity), bytes: &artwork.bytes
        )
        return artwork
    }
}
