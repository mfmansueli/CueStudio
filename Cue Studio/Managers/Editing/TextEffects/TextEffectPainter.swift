//
//  TextEffectPainter.swift
//  Cue Studio
//

import CoreGraphics
import CoreText

/// The brushes text effects paint their layers with, in Core Graphics: a soft blur of a shape (a shadow, a halo), a light or
/// a shade inside a shape's edges (a bevel), a gradient clipped to a shape (metal, a tube's core), an outline wholly outside a
/// shape. Each layer is drawn once into its own small bitmap (`sprite`), kept on the GPU, placed in the drawing's coordinates
/// (from the bottom left, y up, like Core Image), and moved by the composer as the effect plays.
nonisolated enum TextEffectPainter {
    static let colorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// Draws `draw` into a transparent bitmap covering `rect` of the drawing (at `scale`: under 1 for a blurred layer, where
    /// fewer pixels look the same) and returns it placed at `rect`, with its size in bytes. Nil for an empty rect.
    static func sprite(_ rect: CGRect, scale: CGFloat = 1, draw: (CGContext) -> Void) -> (sprite: TextEffectSprite, bytes: Int)? {
        let area = rect.integral
        let width = Int(ceil(area.width * scale))
        let height = Int(ceil(area.height * scale))
        guard width > 0, height > 0, width < 16_384, height < 16_384,
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -area.minX, y: -area.minY)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        draw(context)
        guard let texture = TextEffectRenderer.shared?.texture(from: context) else { return nil }
        let placed = CGRect(x: area.minX, y: area.minY, width: CGFloat(width) / scale, height: CGFloat(height) / scale)
        return (TextEffectSprite(texture: texture, rect: placed), context.bytesPerRow * height)
    }

    /// How many device pixels one of the context's units is (a blur and a shadow's offset are in device pixels).
    private static func deviceScale(_ context: CGContext) -> CGFloat {
        abs(context.ctm.a)
    }

    /// `path` filled with `color`, blurred by `radius`, moved by `offset` (up is positive): only the blur lands, the shape
    /// itself is drawn off the bitmap.
    static func fillBlurred(_ path: CGPath, in context: CGContext, color: TextEffectInk, radius: CGFloat, offset: CGSize = .zero) {
        guard !path.isEmpty, color.alpha > 0.001 else { return }
        let scale = deviceScale(context)
        let far = path.boundingBoxOfPath.maxX + 20_000
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: (far + offset.width) * scale, height: offset.height * scale), blur: max(radius, 0) * scale,
            color: color.cgColor
        )
        context.translateBy(x: -far, y: 0)
        context.addPath(path)
        context.setFillColor(TextEffectInk.black.cgColor)
        context.fillPath()
        context.restoreGState()
    }

    /// A light or a shade inside `path`'s edges, coming from the side `offset` points away from (a highlight on the top
    /// edges with an offset down, a shade on the bottom ones with an offset up).
    static func innerShadow(_ path: CGPath, in context: CGContext, color: TextEffectInk, radius: CGFloat, offset: CGSize) {
        guard !path.isEmpty, color.alpha > 0.001 else { return }
        let scale = deviceScale(context)
        let bounds = path.boundingBoxOfPath
        let margin = radius * 3 + abs(offset.width) + abs(offset.height) + 4
        let far = bounds.maxX + margin + 20_000
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.setShadow(
            offset: CGSize(width: (far + offset.width) * scale, height: offset.height * scale), blur: max(radius, 0) * scale,
            color: color.cgColor
        )
        context.translateBy(x: -far, y: 0)
        // Everything around the shape: its shadow falls inside the shape's edges.
        context.addRect(bounds.insetBy(dx: -margin, dy: -margin))
        context.addPath(path)
        context.setFillColor(TextEffectInk.black.cgColor)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }

    /// `path` filled with a gradient from `start` (the first stop) to `end` (the last), its stops at their fractions.
    static func fillGradient(_ path: CGPath, in context: CGContext, stops: [(CGFloat, TextEffectInk)], from start: CGPoint, to end: CGPoint) {
        guard !path.isEmpty, let gradient = gradient(stops) else { return }
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    static func fill(_ path: CGPath, in context: CGContext, color: TextEffectInk) {
        guard !path.isEmpty, color.alpha > 0.001 else { return }
        context.addPath(path)
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    /// An outline `width` wide wholly outside `path`, with round joins (the shape drawn over it covers the inner half).
    static func strokeOutside(_ path: CGPath, in context: CGContext, color: TextEffectInk, width: CGFloat) {
        guard !path.isEmpty, width > 0, color.alpha > 0.001 else { return }
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width * 2)
        context.setLineJoin(.round)
        context.strokePath()
        // The inside too, so the outline is a solid silhouette even before the shape covers it.
        context.addPath(path)
        context.setFillColor(color.cgColor)
        context.fillPath()
        context.restoreGState()
    }

    /// An outline `width` wide outside `path` (and the inside too, under the shape), painted with a gradient from `start` to
    /// `end`.
    static func strokeGradient(
        _ path: CGPath, in context: CGContext, width: CGFloat, stops: [(CGFloat, TextEffectInk)], from start: CGPoint, to end: CGPoint
    ) {
        guard !path.isEmpty, width > 0, let gradient = gradient(stops) else { return }
        context.saveGState()
        context.addPath(path.copy(strokingWithWidth: width * 2, lineCap: .round, lineJoin: .round, miterLimit: 4))
        context.addPath(path)
        context.clip(using: .winding)
        context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    /// A band `width` wide inside `path` along its edges (a tube's colored rim).
    static func strokeInside(_ path: CGPath, in context: CGContext, color: TextEffectInk, width: CGFloat) {
        guard !path.isEmpty, width > 0, color.alpha > 0.001 else { return }
        context.saveGState()
        context.addPath(path)
        context.clip()
        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width * 2)
        context.strokePath()
        context.restoreGState()
    }

    /// Color glyphs (emoji) as their font draws them.
    static func drawColorGlyphs(_ piece: TextEffectLayout.Piece, in context: CGContext) {
        for glyph in piece.glyphs where glyph.isColor {
            var value = glyph.glyph
            var position = glyph.position
            CTFontDrawGlyphs(glyph.font, &value, &position, 1, context)
        }
    }

    static func gradient(_ stops: [(CGFloat, TextEffectInk)]) -> CGGradient? {
        guard stops.count > 1 else { return nil }
        let colors = stops.map(\.1.cgColor) as CFArray
        var locations = stops.map(\.0)
        return CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)
    }

    /// `path` moved by `offset`.
    static func moved(_ path: CGPath, by offset: CGPoint) -> CGPath {
        var move = CGAffineTransform(translationX: offset.x, y: offset.y)
        return path.copy(using: &move) ?? path
    }
}
