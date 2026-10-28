//
//  TextEffectRendererTests.swift
//  Cue StudioTests
//

import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// The GPU drawing of an effect's frame (`TextEffectRenderer`) keeps what Core Image did: the drawing's y goes up, a rect
/// with fractional edges covers the pixels it crosses partly, a band of light shows only over the faces, and a piece's
/// opacity fades it as a whole.
@Suite("Text effects · GPU drawing")
struct TextEffectRendererTests {
    private let size = CGSize(width: 40, height: 30)

    private var renderer: TextEffectRenderer {
        get throws { try #require(TextEffectRenderer.shared) }
    }

    /// An opaque white square covering `rect` of the drawing.
    private func square(_ rect: CGRect) throws -> TextEffectSprite {
        let painted = TextEffectPainter.sprite(rect) { context in
            context.setFillColor(TextEffectInk.white.cgColor)
            context.fill(rect)
        }
        return try #require(painted?.sprite)
    }

    /// The drawing's alpha at `x`, `y` (from the bottom left, y up), 0 to 255.
    private func alpha(_ image: CIImage?, x: Int, y: Int) throws -> UInt8 {
        let image = try #require(image)
        var pixel = [UInt8](repeating: 0, count: 4)
        TextEffectComposer.context.render(
            image, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: x, y: y, width: 1, height: 1), format: .RGBA8,
            colorSpace: TextEffectPainter.colorSpace
        )
        return pixel[3]
    }

    @Test func theDrawingsYGoesUp() throws {
        let low = try square(CGRect(x: 0, y: 0, width: 10, height: 10))
        let image = try renderer.image(size: size, draws: [TextEffectDraw(low, opacity: 1)], faces: [])
        #expect(try alpha(image, x: 5, y: 5) == 255)
        #expect(try alpha(image, x: 5, y: 25) == 0)
    }

    @Test func aPieceMovesAndFadesAsAWhole() throws {
        let piece = try square(CGRect(x: 0, y: 0, width: 10, height: 10))
        let moved = TextEffectDraw(piece, transform: CGAffineTransform(translationX: 20, y: 10), opacity: 0.5)
        let image = try renderer.image(size: size, draws: [moved], faces: [])
        #expect(try alpha(image, x: 5, y: 5) == 0)
        #expect(abs(Int(try alpha(image, x: 25, y: 15)) - 128) <= 1)
    }

    @Test func aFillCoversTheEdgePixelsItCrossesPartly() throws {
        let band = TextEffectDraw(filling: CGRect(x: 10.25, y: 5, width: 10.5, height: 10), with: .white)
        let image = try renderer.image(size: size, draws: [band], faces: [])
        #expect(try alpha(image, x: 15, y: 10) == 255)
        // Three quarters of the first and the last pixel across.
        #expect(abs(Int(try alpha(image, x: 10, y: 10)) - 191) <= 1)
        #expect(abs(Int(try alpha(image, x: 20, y: 10)) - 191) <= 1)
        #expect(try alpha(image, x: 9, y: 10) == 0)
        #expect(try alpha(image, x: 21, y: 10) == 0)
    }

    @Test func aBandOfLightShowsOnlyOverTheFaces() throws {
        let face = try square(CGRect(x: 0, y: 0, width: 10, height: 30))
        let light = try square(CGRect(x: 0, y: 0, width: 40, height: 30))
        let band = TextEffectDraw(light, opacity: 1, isMasked: true)
        let image = try renderer.image(size: size, draws: [band], faces: [TextEffectDraw(face, opacity: 1)])
        #expect(try alpha(image, x: 5, y: 15) == 255)
        #expect(try alpha(image, x: 25, y: 15) == 0)
        // Over no faces it shows nowhere.
        let alone = try renderer.image(size: size, draws: [band], faces: [])
        #expect(try alpha(alone, x: 5, y: 15) == 0)
    }

    @Test func aClipCutsWhatGoesPastIt() throws {
        let piece = try square(CGRect(x: 0, y: 0, width: 40, height: 30))
        var draw = TextEffectDraw(piece, opacity: 1)
        draw.clip = CGRect(x: 0, y: 10, width: 40, height: 10.5)
        let image = try renderer.image(size: size, draws: [draw], faces: [])
        #expect(try alpha(image, x: 20, y: 5) == 0)
        #expect(try alpha(image, x: 20, y: 15) == 255)
        #expect(abs(Int(try alpha(image, x: 20, y: 20)) - 128) <= 1)
    }
}
