//
//  TextEffectPainter+Gold.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Gold: polished metal in tonal bands (`TextEffectMetal`), a slight bevel (light inside the top edges, shade inside the
/// bottom ones), a dark edge that holds the letters over a bright picture, a soft shadow, a glint that crosses once as it
/// comes in, and a few short sparkles where the glint passes.
nonisolated extension TextEffectPainter {
    static func gold(_ layout: TextEffectLayout, _ request: TextEffectRequest) -> TextEffectArtwork {
        let size = request.pointSize
        let shine = request.effect.intensity
        let metal = TextEffectMetal(request.effect.tone)
        var artwork = TextEffectArtwork()
        artwork.layers.append(layer(.shadow, layout, margin: size * 0.24, bytes: &artwork.bytes) { context, piece in
            dropShadow(piece, in: context, size: size, strength: 1.1)
        })
        artwork.layers.append(layer(.body, layout, margin: size * 0.08, bytes: &artwork.bytes) { context, piece in
            // A thin dark edge outside a bevelled metal frame: the letters stand out of the picture like a struck medal.
            strokeOutside(piece.outline, in: context, color: metal.edge.opacity(0.95), width: size * 0.048)
            let span = gradientSpan(piece, in: layout)
            strokeGradient(piece.outline, in: context, width: size * 0.034, stops: metal.frame, from: span.bottom, to: span.top)
        })
        let stops = metal.bands(shine: shine)
        artwork.layers.append(layer(.face, layout, margin: size * 0.02, bytes: &artwork.bytes) { context, piece in
            let span = gradientSpan(piece, in: layout)
            fillGradient(piece.outline, in: context, stops: stops, from: span.bottom, to: span.top)
            // The bevel: light along the top edges, shade along the bottom ones.
            innerShadow(
                piece.outline, in: context, color: TextEffectInk.white.opacity(0.35 + 0.45 * shine), radius: size * 0.022,
                offset: CGSize(width: 0, height: -size * 0.022)
            )
            innerShadow(
                piece.outline, in: context, color: metal.shade.opacity(0.65), radius: size * 0.04,
                offset: CGSize(width: 0, height: size * 0.03)
            )
            drawColorGlyphs(piece, in: context)
        })
        let bounds = layout.textBounds
        artwork.sweep = band(
            width: size * 0.55, height: (bounds.height + size) * 1.6, color: metal.glint.opacity(0.55 + 0.4 * shine), bytes: &artwork.bytes
        )
        artwork.sparkleSize = 96
        artwork.sparkle = sparkle(diameter: artwork.sparkleSize, tint: metal.glint, bytes: &artwork.bytes)
        artwork.sparkles = sparkles(layout, request)
        return artwork
    }

    /// A four-pointed twinkle `diameter` wide, centered on the origin: a hot core, long rays across, short ones between.
    private static func sparkle(diameter: CGFloat, tint: TextEffectInk, bytes: inout Int) -> TextEffectSprite? {
        let half = diameter / 2
        let drawn = sprite(CGRect(x: -half, y: -half, width: diameter, height: diameter)) { context in
            func ray(length: CGFloat, width: CGFloat, angle: CGFloat) -> CGPath {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: length))
                path.addQuadCurve(to: CGPoint(x: 0, y: -length), control: CGPoint(x: width, y: 0))
                path.addQuadCurve(to: CGPoint(x: 0, y: length), control: CGPoint(x: -width, y: 0))
                var turn = CGAffineTransform(rotationAngle: angle)
                return path.copy(using: &turn) ?? path
            }
            let rays = CGMutablePath()
            rays.addPath(ray(length: half * 0.96, width: half * 0.1, angle: 0))
            rays.addPath(ray(length: half * 0.96, width: half * 0.1, angle: .pi / 2))
            rays.addPath(ray(length: half * 0.42, width: half * 0.06, angle: .pi / 4))
            rays.addPath(ray(length: half * 0.42, width: half * 0.06, angle: -.pi / 4))
            fillBlurred(rays, in: context, color: tint.opacity(0.9), radius: half * 0.08)
            fill(rays, in: context, color: TextEffectInk.white.opacity(0.95))
            if let core = gradient([(0, TextEffectInk.white), (0.35, tint.opacity(0.7)), (1, tint.opacity(0))]) {
                context.drawRadialGradient(
                    core, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: half * 0.42, options: []
                )
            }
        }
        bytes += drawn?.bytes ?? 0
        return drawn?.sprite
    }

    /// Where the sparkles show: a few over the tops of the letters, chosen from the words so they are the same every time.
    private static func sparkles(_ layout: TextEffectLayout, _ request: TextEffectRequest) -> [TextEffectSparkle] {
        let pieces = layout.pieces.filter { !$0.outline.isEmpty }
        guard !pieces.isEmpty else { return [] }
        let bounds = layout.textBounds
        let size = request.pointSize
        var random = TextEffectRandom(seed: seed(request.string.string + "gold"))
        let count = min(Int((3 + 5 * request.effect.intensity).rounded()), max(3, pieces.count))
        return (0..<count).map { index in
            // Spread along the text: each in its own stretch, somewhere in it.
            let slot = (Double(index) + 0.2 + 0.6 * random.next()) / Double(count)
            let x = bounds.minX + CGFloat(slot) * bounds.width
            let piece = pieces.min { abs($0.anchor.x - x) < abs($1.anchor.x - x) } ?? pieces[0]
            let line = layout.lines[piece.line]
            let cap = line.capHeight > 0 ? line.capHeight : line.ascent * 0.7
            let y = piece.baseline + cap * CGFloat(0.55 + 0.5 * random.next())
            return TextEffectSparkle(
                position: CGPoint(x: x, y: y), size: size * CGFloat(0.26 + 0.2 * random.next()), along: slot,
                spin: CGFloat(random.next() * 0.7), onExit: index % 3 == 1
            )
        }
    }
}
