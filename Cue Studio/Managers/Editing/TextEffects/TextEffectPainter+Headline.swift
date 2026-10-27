//
//  TextEffectPainter+Headline.swift
//  Cue Studio
//

import CoreGraphics

/// Headline: crisp words over a band behind each line, in the accent color. Band height (the effect's intensity) goes from
/// a marker underline to a full band; the words keep a soft shadow while they still sit on the picture. Each line has the
/// room its words come in through: they rise from under its bottom edge (or drop from over its top), so they appear out of
/// the line itself.
nonisolated extension TextEffectPainter {
    static func headline(_ layout: TextEffectLayout, _ request: TextEffectRequest) -> TextEffectArtwork {
        let size = request.pointSize
        let height = request.effect.intensity
        var artwork = TextEffectArtwork()
        if height < 0.6 {
            artwork.layers.append(layer(.shadow, layout, margin: size * 0.24, bytes: &artwork.bytes) { context, piece in
                dropShadow(piece, in: context, size: size, strength: 1 - height)
            })
        }
        artwork.layers.append(layer(.face, layout, margin: size * 0.02, bytes: &artwork.bytes) { context, piece in
            fill(piece.outline, in: context, color: request.color)
            drawColorGlyphs(piece, in: context)
        })
        artwork.bandColor = request.accent
        let rises = request.effect.direction != .down
        for line in layout.lines {
            let cap = line.capHeight > 0 ? line.capHeight : line.ascent * 0.7
            let side = size * 0.2
            // A full band hugs the line from under its descenders to over its capitals; an underline sits under the baseline.
            let fullBottom = line.baseline - line.descent - size * 0.06
            let fullTop = line.baseline + max(cap, line.ascent * 0.82) + size * 0.12
            let lineBottom = line.baseline - line.descent * 0.55 - size * 0.04
            let bottom = lineBottom + (fullBottom - lineBottom) * CGFloat(height)
            let top = (lineBottom + size * 0.11) + (fullTop - lineBottom - size * 0.11) * CGFloat(height)
            artwork.bands.append(CGRect(x: line.bounds.minX - side, y: bottom, width: line.bounds.width + side * 2, height: top - bottom))
            // The edge the words come through is the line's own; the other one is open, so an accent is never cut.
            let edgeBottom = min(bottom, line.baseline - line.descent)
            let edgeTop = max(top, line.baseline + line.ascent)
            let open = size * 1.2
            artwork.clips.append(
                rises
                    ? CGRect(x: line.bounds.minX - open, y: edgeBottom, width: line.bounds.width + open * 2, height: edgeTop - edgeBottom + open)
                    : CGRect(x: line.bounds.minX - open, y: edgeBottom - open, width: line.bounds.width + open * 2, height: edgeTop - edgeBottom + open)
            )
        }
        return artwork
    }

    /// The recipe for `request`'s kind.
    static func artwork(_ layout: TextEffectLayout, _ request: TextEffectRequest) -> TextEffectArtwork {
        switch request.effect.kind {
        case .gold: gold(layout, request)
        case .wave: wave(layout, request)
        case .pop3D: pop(layout, request)
        case .neon: neon(layout, request)
        case .headline: headline(layout, request)
        case .sheen: sheen(layout, request)
        }
    }
}
