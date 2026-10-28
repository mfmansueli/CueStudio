//
//  TextEffectDraw.swift
//  Cue Studio
//

import CoreGraphics
import Metal

/// One quad of a text effect's frame (`TextEffectRenderer`): a sprite moved by `transform` and faded, or a rect filled with a
/// color; cut to `clip` when there is one, and shown only over the faces when it is a band of light.
nonisolated struct TextEffectDraw: @unchecked Sendable {
    /// Nil for a fill.
    let texture: MTLTexture?
    let rect: CGRect
    var transform: CGAffineTransform = .identity
    /// Linear light, premultiplied: what the sprite's pixels are multiplied by, or the fill's color.
    var tint: SIMD4<Float>
    /// In the drawing's pixels; nil draws it whole. A pixel its edge crosses keeps the part inside.
    var clip: CGRect?
    var isMasked = false

    /// A clip that cuts nothing.
    private static let everywhere = SIMD4<Float>(-1e9, -1e9, 1e9, 1e9)

    /// `sprite` moved by `transform`, at `opacity`.
    init(_ sprite: TextEffectSprite, transform: CGAffineTransform = .identity, opacity: CGFloat, isMasked: Bool = false) {
        texture = sprite.texture
        rect = sprite.rect
        self.transform = transform
        let alpha = Float(min(1, max(0, opacity)))
        tint = SIMD4(repeating: alpha)
        self.isMasked = isMasked
    }

    /// `rect` filled with `ink`, the pixels its edges cross partly.
    init(filling rect: CGRect, with ink: TextEffectInk) {
        texture = nil
        self.rect = rect.insetBy(dx: -1, dy: -1)
        tint = ink.linearPremultiplied
        clip = rect
    }

    /// Its four corners in the order a triangle strip takes them, each with where it reads the sprite (whose rows go down).
    var corners: [SIMD4<Float>] {
        [
            (CGPoint(x: rect.minX, y: rect.minY), SIMD2<Float>(0, 1)), (CGPoint(x: rect.maxX, y: rect.minY), SIMD2<Float>(1, 1)),
            (CGPoint(x: rect.minX, y: rect.maxY), SIMD2<Float>(0, 0)), (CGPoint(x: rect.maxX, y: rect.maxY), SIMD2<Float>(1, 0)),
        ].map { point, uv in
            let placed = point.applying(transform)
            return SIMD4(Float(placed.x), Float(placed.y), uv.x, uv.y)
        }
    }

    /// Its tint, and its clip in the pixels of a target `height` tall counted from the top.
    func look(height: Int) -> [SIMD4<Float>] {
        guard let clip else { return [tint, Self.everywhere] }
        let top = CGFloat(height) - clip.maxY
        let bottom = CGFloat(height) - clip.minY
        return [tint, SIMD4(Float(clip.minX), Float(top), Float(clip.maxX), Float(bottom))]
    }
}
