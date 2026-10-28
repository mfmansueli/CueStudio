//
//  TextEffectPainter+Pop.swift
//  Cue Studio
//

import CoreGraphics

/// Pop 3D: chunky letters with depth: the face in the text's color (lit at the top, a gloss over its upper half), the
/// depth in the accent color stepping back toward the direction picked, darker as it goes, one dark outline around face
/// and depth together, and a soft shadow under it all.
nonisolated extension TextEffectPainter {
    /// Which way the depth goes, a unit step in the drawing (y up).
    static func depthStep(_ direction: TextEffectDirection) -> CGPoint {
        switch direction {
        case .left: CGPoint(x: -0.6, y: -0.8)
        case .down: CGPoint(x: 0, y: -1)
        default: CGPoint(x: 0.6, y: -0.8)
        }
    }

    /// How deep the letters are, in pixels.
    static func depth(_ request: TextEffectRequest) -> CGFloat {
        request.pointSize * CGFloat(0.05 + 0.12 * request.effect.intensity)
    }

    static func pop(_ layout: TextEffectLayout, _ request: TextEffectRequest) -> TextEffectArtwork {
        let size = request.pointSize
        let color = request.color
        let accent = request.accent
        let step = depthStep(request.effect.direction)
        let length = depth(request)
        // A step a pixel and a half long: smooth sides without drawing the letter a hundred times.
        let steps = max(2, Int((length / 1.5).rounded(.up)))
        let outline = TextEffectInk(hex: 0x16121C)
        let margin = length + size * 0.12
        func extruded(_ piece: TextEffectLayout.Piece) -> CGPath {
            let path = CGMutablePath()
            for index in 0...steps {
                let part = length * CGFloat(index) / CGFloat(steps)
                path.addPath(moved(piece.outline, by: CGPoint(x: step.x * part, y: step.y * part)))
            }
            return path
        }
        var artwork = TextEffectArtwork()
        artwork.layers.append(layer(.shadow, layout, margin: margin + size * 0.2, bytes: &artwork.bytes) { context, piece in
            let shape = piece.hasColorGlyphs ? silhouette(piece) : moved(piece.outline, by: CGPoint(x: step.x * length, y: step.y * length))
            fillBlurred(
                shape, in: context, color: TextEffectInk.black.opacity(0.42), radius: size * 0.06,
                offset: CGSize(width: step.x * size * 0.03, height: -size * 0.05)
            )
        })
        artwork.layers.append(layer(.body, layout, margin: margin, bytes: &artwork.bytes) { context, piece in
            strokeOutside(extruded(piece), in: context, color: outline, width: size * 0.05)
        })
        artwork.layers.append(layer(.body, layout, margin: margin, bytes: &artwork.bytes) { context, piece in
            // From the farthest step to the nearest: darker away from the face.
            for index in stride(from: steps, through: 1, by: -1) {
                let part = CGFloat(index) / CGFloat(steps)
                let shift = CGPoint(x: step.x * length * part, y: step.y * length * part)
                fill(moved(piece.outline, by: shift), in: context, color: accent.darkened(0.08 + 0.34 * Double(part)))
            }
        })
        artwork.layers.append(layer(.face, layout, margin: size * 0.03, bytes: &artwork.bytes) { context, piece in
            let span = gradientSpan(piece, in: layout)
            fillGradient(
                piece.outline, in: context, stops: [(0, color.darkened(0.07)), (0.6, color), (1, color.lightened(0.2))],
                from: span.bottom, to: span.top
            )
            // A gloss over the upper half, fading to nothing at the middle.
            let middle = CGPoint(x: 0, y: (span.bottom.y + span.top.y) / 2)
            fillGradient(
                piece.outline, in: context, stops: [(0, TextEffectInk.white.opacity(0)), (1, TextEffectInk.white.opacity(0.3))],
                from: middle, to: span.top
            )
            innerShadow(
                piece.outline, in: context, color: TextEffectInk.black.opacity(0.22), radius: size * 0.035,
                offset: CGSize(width: 0, height: size * 0.025)
            )
            innerShadow(
                piece.outline, in: context, color: TextEffectInk.white.opacity(0.5), radius: size * 0.012,
                offset: CGSize(width: 0, height: -size * 0.014)
            )
            drawColorGlyphs(piece, in: context)
        })
        return artwork
    }
}
