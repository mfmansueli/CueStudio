//
//  TextEffectPainter+Neon.swift
//  Cue Studio
//

import CoreGraphics

/// Neon: a tube in the text's color. The letter itself is the bright core, nearly white with a rim of the tint inside its
/// edges, so the font's shapes read crisp; around it a tight bloom and a wide soft halo; behind it a faint dark veil so it
/// holds over a bright picture; and the tube unlit, dim and tinted, for the moment before it lights.
nonisolated extension TextEffectPainter {
    /// The tube's light: the text's color, much more vivid (a pastel lights as its saturated self); a dark one glows as a
    /// hot pink (an ink tube doesn't light).
    static func neonTint(_ color: TextEffectInk) -> TextEffectInk {
        color.luminance < 0.06 ? TextEffectInk(hex: 0xFF3DA8) : color.saturated(0.9)
    }

    static func neon(_ layout: TextEffectLayout, _ request: TextEffectRequest) -> TextEffectArtwork {
        let size = request.pointSize
        let glow = request.effect.intensity
        let tint = neonTint(request.color)
        let wide = size * CGFloat(0.14 + 0.26 * glow)
        var artwork = TextEffectArtwork()
        // Blurred layers at half the pixels: a blur looks the same with fewer.
        artwork.layers.append(layer(.backing, layout, margin: size * 0.5, scale: 0.5, bytes: &artwork.bytes) { context, piece in
            fillBlurred(silhouette(piece), in: context, color: TextEffectInk.black.opacity(0.4), radius: size * 0.18)
        })
        artwork.layers.append(layer(.halo, layout, margin: wide * 2.4, scale: 0.5, bytes: &artwork.bytes) { context, piece in
            // Wide and faint, then nearer and stronger, then a bloom hugging the tube: light falling off as it spreads.
            fillBlurred(piece.outline, in: context, color: tint.opacity(0.4 + 0.3 * glow), radius: wide)
            fillBlurred(piece.outline, in: context, color: tint.opacity(0.8), radius: size * 0.08)
            fillBlurred(piece.outline, in: context, color: tint.lightened(0.25).opacity(0.95), radius: size * 0.025)
        })
        artwork.layers.append(layer(.unlit, layout, margin: size * 0.02, bytes: &artwork.bytes) { context, piece in
            fill(piece.outline, in: context, color: tint.darkened(0.55).opacity(0.85))
            strokeInside(piece.outline, in: context, color: tint.darkened(0.25).opacity(0.9), width: size * 0.02)
        })
        artwork.layers.append(layer(.face, layout, margin: size * 0.02, bytes: &artwork.bytes) { context, piece in
            // A white-hot core with the tint along its edges: the letter's own shape, crisp inside its light.
            fill(piece.outline, in: context, color: tint.mixed(with: .white, 0.82))
            strokeInside(piece.outline, in: context, color: tint.lightened(0.15), width: size * 0.026)
            drawColorGlyphs(piece, in: context)
        })
        return artwork
    }
}
