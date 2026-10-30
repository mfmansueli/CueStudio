//
//  TextEffectRenderingTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// The six effects as the preview and the export draw them: letters cut where the writing allows (an accent stays on its
/// letter, an emoji is one piece, Arabic and Hindi move by word), the same picture for the same moment whatever came before,
/// still while the text is read and when its motion is off, and a text resized as a whole growing as one, its lines breaking
/// where they did.
@Suite("Text effects · rendering")
struct TextEffectRenderingTests {
    private static let frameWidth: CGFloat = 1080
    private let span = TimeSpan(start: 0, end: 4)

    private func text(_ preset: TypePreset, _ words: String) -> TextOverlay {
        var text = TextOverlay(role: .title, look: preset.look(for: .title), preset: preset, span: span)
        text.text = words
        return text
    }

    private func request(_ text: TextOverlay) throws -> TextEffectRequest {
        try #require(TextOverlayRenderer.effectRequest(for: text, frameWidth: Self.frameWidth, widthFraction: TextOverlayRenderer.maxWidthFraction))
    }

    /// The picture's pixels, to compare two drawings exactly.
    private func pixels(_ image: CIImage?) throws -> Data {
        let image = try #require(image)
        let cgImage = try #require(
            TextEffectComposer.context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: TextEffectPainter.colorSpace)
        )
        return try #require(cgImage.dataProvider?.data as Data?)
    }

    // MARK: - Pieces

    @Test func lettersAreCutWhereTheWritingAllows() throws {
        // "ç", "ã" written with a combining mark, a skin-toned emoji and a family: each one piece.
        let words = "Ação ç\u{0301} 👩🏽‍💻 👨‍👩‍👧"
        let layout = try #require(TextEffectCache.shared.layout(for: try request(text(.gold, words))))
        #expect(!layout.piecesAreWords)
        let expected = words.filter { !$0.isWhitespace }.count
        #expect(layout.pieces.count == expected, "\(layout.pieces.count) pieces for \(expected) letters")
        // No piece starts inside a letter.
        let string = words as NSString
        for piece in layout.pieces {
            let range = string.rangeOfComposedCharacterSequences(for: piece.range)
            #expect(range == piece.range, "\(piece.range)")
        }
    }

    @Test(arguments: ["مرحبا بكم في القناة", "नमस्ते दोस्तों", "สวัสดี ทุกคน"])
    func joinedWritingMovesByWord(_ words: String) throws {
        let layout = try #require(TextEffectCache.shared.layout(for: try request(text(.wave, words))))
        #expect(layout.piecesAreWords)
        #expect(layout.pieces.count == words.split(whereSeparator: \.isWhitespace).count)
    }

    @Test func aWordOnTwoLinesIsAPieceOnEachAndNoLetterIsCut() throws {
        // Thai has no spaces inside a phrase: Core Text breaks the line between its words.
        let words = "สวัสดีครับทุกคนที่ติดตามช่องของเรา ขอบคุณ"
        let layout = try #require(TextEffectCache.shared.layout(for: try request(text(.wave, words))))
        let string = words as NSString
        var covered = 0
        for piece in layout.pieces {
            #expect(string.rangeOfComposedCharacterSequences(for: piece.range) == piece.range, "\(piece.range)")
            #expect(!string.substring(with: piece.range).contains { $0.isWhitespace })
            covered += piece.range.length
        }
        #expect(covered == words.utf16.count - 1)
    }

    @Test func arabicReadsFromTheRight() throws {
        let layout = try #require(TextEffectCache.shared.layout(for: try request(text(.neon, "مرحبا بكم"))))
        #expect(layout.isRightToLeft)
    }

    @Test func aLongTextAndHeadlineMoveByWord() throws {
        #expect(try request(text(.headline, "Três dicas")).byWords)
        let long = String(repeating: "palavra ", count: 8)
        #expect(try request(text(.gold, long)).byWords)
        #expect(try !request(text(.gold, "Curto")).byWords)
    }

    // MARK: - Time

    @Test(arguments: TypePreset.effectPresets)
    func theSameMomentIsTheSamePicture(_ preset: TypePreset) throws {
        let request = try request(text(preset, "Olá, tudo bem?"))
        let sprites = try #require(TextEffectCache.shared.sprites(for: request))
        let effect = request.effect
        let first = try pixels(TextEffectComposer.image(sprites, effect: effect, time: 0.37, length: 4))
        // Another moment drawn in between changes nothing.
        _ = TextEffectComposer.image(sprites, effect: effect, time: 3.7, length: 4)
        let again = try pixels(TextEffectComposer.image(sprites, effect: effect, time: 0.37, length: 4))
        #expect(first == again)
        // A fresh painting of the same text draws it the same.
        let layout = try #require(TextEffectCache.shared.layout(for: request))
        let fresh = try #require(TextEffectSprites.make(request, layout: layout))
        #expect(try pixels(TextEffectComposer.image(fresh, effect: effect, time: 0.37, length: 4)) == first)
    }

    @Test(arguments: TypePreset.effectPresets)
    func nothingMovesWhileTheTextIsRead(_ preset: TypePreset) throws {
        let request = try request(text(preset, "Leia com calma"))
        let sprites = try #require(TextEffectCache.shared.sprites(for: request))
        let rest = try pixels(sprites.rest())
        #expect(try pixels(TextEffectComposer.image(sprites, effect: request.effect, time: 2, length: 4)) == rest)
        #expect(try pixels(TextEffectComposer.image(sprites, effect: request.effect, time: 2.6, length: 4)) == rest)
        // Its way in is not the rest.
        #expect(try pixels(TextEffectComposer.image(sprites, effect: request.effect, time: 0.1, length: 4)) != rest)
    }

    @Test(arguments: TypePreset.effectPresets)
    func aStillEffectKeepsItsFinishTheWholeTime(_ preset: TypePreset) throws {
        var still = text(preset, "Sem movimento")
        still.effect?.motion = .still
        let request = try request(still)
        let playback = TextEffectPlayback(request: request, length: 4, animates: still.playsEffectMotion)
        let sprites = try #require(TextEffectCache.shared.sprites(for: request))
        let rest = try pixels(sprites.rest())
        for time in [0.0, 0.2, 2, 3.9] {
            #expect(try pixels(playback.image(at: time)) == rest, "\(time)")
        }
    }

    // MARK: - Size

    @Test(arguments: [TypePreset.orbit, .gold, .headline])
    func aTextResizedAsAWholeGrowsAsOne(_ preset: TypePreset) throws {
        var small = text(preset, "Uma frase que quebra em duas linhas")
        small.block = TextBlock(width: TextOverlayRenderer.currentLineWidth(of: small), size: small.size)
        var big = small
        big.size = small.size * 2
        let smallBox = TextOverlayRenderer.size(for: small, frameWidth: Self.frameWidth)
        let bigBox = TextOverlayRenderer.size(for: big, frameWidth: Self.frameWidth)
        // Twice as big each way, give or take the rounding of each line: the same lines, twice as big.
        #expect(abs(bigBox.width / smallBox.width - 2) < 0.03, "\(smallBox) → \(bigBox)")
        #expect(abs(bigBox.height / smallBox.height - 2) < 0.03, "\(smallBox) → \(bigBox)")
    }

    @Test func aSideHandleNeverCutsAWord() {
        var text = text(.orbit, "Extraordinário sim")
        // Small enough to fit on one line.
        text.size = 24
        let longest = TextOverlayRenderer.longestWordWidth(of: text)
        let narrow = OverlaysViewModel.text(text, withLineWidth: longest)
        let box = TextOverlayRenderer.size(for: narrow, frameWidth: TextOverlayRenderer.referenceWidth)
        // One word a line: two lines, the long word whole on its own.
        let line = TextOverlayRenderer.size(for: text, frameWidth: TextOverlayRenderer.referenceWidth)
        #expect(box.height > line.height * 1.4, "\(line) → \(box)")
        #expect(box.width < line.width)
    }

    @Test func theOutlineAndTheShadowStayInsideTheDrawing() throws {
        var outlined = text(.orbit, "ola tudo bem")
        outlined.hasOutline = true
        outlined.hasShadow = true
        let drawing = try #require(TextOverlayRenderer.drawing(for: outlined, frameWidth: Self.frameWidth))
        let cgImage = try #require(drawing.image.cgImage)
        // Nothing drawn on the picture's edge: the outline and the shadow had room.
        let data = try #require(cgImage.dataProvider?.data as Data?)
        let bytesPerRow = cgImage.bytesPerRow
        var edge = 0
        for x in 0..<cgImage.width {
            edge = max(edge, Int(data[x * 4 + 3]), Int(data[(cgImage.height - 1) * bytesPerRow + x * 4 + 3]))
        }
        #expect(edge < 8, "alpha \(edge) on the top or bottom edge")
    }
}
