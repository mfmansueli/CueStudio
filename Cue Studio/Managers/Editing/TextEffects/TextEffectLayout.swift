//
//  TextEffectLayout.swift
//  Cue Studio
//

import CoreGraphics
import CoreText
import Foundation
import NaturalLanguage

/// A text laid out once by Core Text for an effect, cut into the pieces its motion moves: one per letter as the reader sees
/// it (a grapheme: "á" written with a combining accent, a flag, a family emoji are one), or one per word where letters join
/// or stack (Arabic, the Indic scripts, Thai) and for effects that read by word. Every piece keeps the glyphs, positions and
/// shapes the whole line gave it, so kerning, contextual forms and Arabic's joined letters stay as the font drew them, and
/// a still effect looks exactly like the line. Coordinates are the drawing's, from its bottom left, y up (Core Image's).
nonisolated struct TextEffectLayout: @unchecked Sendable {
    struct Glyph {
        let font: CTFont
        let glyph: CGGlyph
        /// Its origin on the baseline, in the drawing.
        let position: CGPoint
        /// A color glyph (an emoji): drawn as the font draws it, never filled with the effect's material.
        let isColor: Bool
    }

    struct Piece {
        let index: Int
        let line: Int
        /// The word it belongs to, counted over the whole text.
        let word: Int
        /// The characters it draws (UTF-16, in the text).
        let range: NSRange
        let glyphs: [Glyph]
        /// The outlines of its glyphs, overlaps removed (a variable font's letters are made of overlapping parts, whose seams
        /// a stroke or a bevel would show); empty for color glyphs.
        let outline: CGPath
        /// Where it sits on its line: from its first glyph's origin to its last glyph's advance, baseline to ascent and
        /// descent.
        let bounds: CGRect
        let baseline: CGFloat
        /// Whether any of its glyphs is a color glyph.
        var hasColorGlyphs: Bool { glyphs.contains(where: \.isColor) }
        /// Where it turns and grows from: the middle of its letters.
        var anchor: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
        /// Everything it inks: its line's height and its outlines (an accent above a capital reaches past the line).
        var inkBounds: CGRect { outline.isEmpty ? bounds : bounds.union(outline.boundingBoxOfPath) }
    }

    struct Line {
        /// From the left of its first piece to the right of its last, ascent to descent.
        let bounds: CGRect
        let baseline: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        let capHeight: CGFloat
        let xHeight: CGFloat
    }

    /// The text's box: its lines and the padding around them. What the editor outlines and places.
    let boxSize: CGSize
    /// Extra room on every side of the box that the effect draws in (halos, depth, sparkles, a wave's travel), so the
    /// drawing is `boxSize` grown by it and centered on the same point.
    let room: CGFloat
    let pieces: [Piece]
    let lines: [Line]
    let pointSize: CGFloat
    let isRightToLeft: Bool
    /// The pieces are words.
    let piecesAreWords: Bool

    /// The drawing's size: the box with its room.
    var drawingSize: CGSize { CGSize(width: boxSize.width + room * 2, height: boxSize.height + room * 2) }
    /// Every piece's letters together.
    var textBounds: CGRect { lines.reduce(CGRect.null) { $0.union($1.bounds) } }

    /// A piece as Core Text placed it, before the drawing's margins.
    private struct RawPiece {
        let line: Int
        var range: NSRange
        var glyphs: [Glyph]
    }

    /// The text's characters, read once: what word and what letter each belongs to.
    private struct Reading {
        let text: NSString
        let words: [Int]
        let clusters: [Int]
        let byWords: Bool

        /// The piece a character belongs to; nil for a space.
        func key(of character: Int) -> Int? {
            guard character >= 0, character < text.length, !TextEffectLayout.isWhitespace(text.character(at: character)) else { return nil }
            let key = byWords ? words[character] : clusters[character]
            return key >= 0 ? key : nil
        }
    }

    /// Lays out `string` (Core Text attributes: font, kern, paragraph style) in lines at most `maxWidth` wide, with
    /// `padding` around them and `room` for the effect; cut by word when `byWords`, else by letter. Nil when there is
    /// nothing to draw.
    static func make(_ string: NSAttributedString, maxWidth: CGFloat, padding: CGSize, room: CGFloat, byWords: Bool) -> TextEffectLayout? {
        guard string.length > 0, maxWidth > 0 else { return nil }
        let framesetter = CTFramesetterCreateWithAttributedString(string as CFAttributedString)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: maxWidth, height: 100_000), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        let ctLines = (CTFrameGetLines(frame) as? [CTLine]) ?? []
        guard !ctLines.isEmpty else { return nil }
        var origins = [CGPoint](repeating: .zero, count: ctLines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

        let text = string.string as NSString
        let reading = Reading(text: text, words: wordIndices(of: text), clusters: clusterStarts(of: text), byWords: byWords)
        var rawPieces: [RawPiece] = []
        var rawLines: [Line] = []
        var rightToLeft = false
        for (index, line) in ctLines.enumerated() {
            let read = read(line, index: index, origin: origins[index], reading: reading, into: &rawPieces)
            rawLines.append(read.line)
            rightToLeft = rightToLeft || read.rightToLeft
        }
        guard !rawPieces.isEmpty else { return nil }

        // The lines' letters span this; the box hugs them, with the padding around.
        let content = rawLines.reduce(CGRect.null) { $0.union($1.bounds) }
        let shift = CGPoint(x: room + padding.width - content.minX, y: room + padding.height - content.minY)
        let boxSize = CGSize(width: ceil(content.width + padding.width * 2), height: ceil(content.height + padding.height * 2))
        let lines = rawLines.map { raw in
            Line(
                bounds: raw.bounds.offsetBy(dx: shift.x, dy: shift.y), baseline: raw.baseline + shift.y, ascent: raw.ascent,
                descent: raw.descent, capHeight: raw.capHeight, xHeight: raw.xHeight
            )
        }
        // Pieces in the order they're read: by where their characters are in the text, which also puts Arabic's first word
        // (at the right) first.
        let ordered = rawPieces.sorted { $0.range.location < $1.range.location }
        let pieces = ordered.enumerated().map { index, raw in
            piece(raw, index: index, line: lines[raw.line], shift: shift, word: reading.words[raw.range.location])
        }
        let pointSize = pieces.first?.glyphs.first.map { CTFontGetSize($0.font) } ?? 0
        return TextEffectLayout(
            boxSize: boxSize, room: room, pieces: pieces, lines: lines, pointSize: pointSize, isRightToLeft: rightToLeft,
            piecesAreWords: byWords
        )
    }

    /// One line's glyphs, gathered into its pieces (added to `pieces`), and the line's measures.
    private static func read(
        _ line: CTLine, index lineIndex: Int, origin: CGPoint, reading: Reading, into pieces: inout [RawPiece]
    ) -> (line: Line, rightToLeft: Bool) {
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        var pieceOfKey: [Int: Int] = [:]
        var lineRect = CGRect.null
        var capHeight: CGFloat = 0
        var xHeight: CGFloat = 0
        var rightToLeft = false
        for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
            let count = CTRunGetGlyphCount(run)
            // The font Core Text actually drew with: a fallback for letters the face lacks.
            guard count > 0, let fontValue = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] else { continue }
            if CTRunGetStatus(run).contains(.rightToLeft) { rightToLeft = true }
            let font = fontValue as! CTFont // swiftlint:disable:this force_cast
            let isColor = CTFontGetSymbolicTraits(font).contains(.traitColorGlyphs)
            capHeight = max(capHeight, CTFontGetCapHeight(font))
            xHeight = max(xHeight, CTFontGetXHeight(font))
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var advances = [CGSize](repeating: .zero, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            let all = CFRange(location: 0, length: 0)
            CTRunGetGlyphs(run, all, &glyphs)
            CTRunGetPositions(run, all, &positions)
            CTRunGetAdvances(run, all, &advances)
            CTRunGetStringIndices(run, all, &indices)
            for index in 0..<count {
                // Spaces and line ends are no piece: nothing to see.
                guard let key = reading.key(of: indices[index]) else { continue }
                // The whole letter: a glyph can stand for a letter and its marks (ç with an acute is one glyph).
                let character = reading.text.rangeOfComposedCharacterSequence(at: indices[index])
                let point = CGPoint(x: origin.x + positions[index].x, y: origin.y + positions[index].y)
                let glyph = Glyph(font: font, glyph: glyphs[index], position: point, isColor: isColor)
                lineRect = lineRect.union(CGRect(x: point.x, y: origin.y - descent, width: max(advances[index].width, 0.5), height: ascent + descent))
                if let existing = pieceOfKey[key] {
                    pieces[existing].glyphs.append(glyph)
                    pieces[existing].range = NSUnionRange(pieces[existing].range, character)
                } else {
                    pieceOfKey[key] = pieces.count
                    pieces.append(RawPiece(line: lineIndex, range: character, glyphs: [glyph]))
                }
            }
        }
        if lineRect.isNull { lineRect = CGRect(x: origin.x, y: origin.y - descent, width: 0, height: ascent + descent) }
        let measures = Line(bounds: lineRect, baseline: origin.y, ascent: ascent, descent: descent, capHeight: capHeight, xHeight: xHeight)
        return (measures, rightToLeft)
    }

    /// A piece in the drawing: its glyphs moved by `shift`, its outlines joined, its place on its line.
    private static func piece(_ raw: RawPiece, index: Int, line: Line, shift: CGPoint, word: Int) -> Piece {
        let glyphs = raw.glyphs.map { glyph in
            Glyph(
                font: glyph.font, glyph: glyph.glyph, position: CGPoint(x: glyph.position.x + shift.x, y: glyph.position.y + shift.y),
                isColor: glyph.isColor
            )
        }
        var left = CGFloat.greatestFiniteMagnitude
        var right = -CGFloat.greatestFiniteMagnitude
        let outline = CGMutablePath()
        for glyph in glyphs {
            var advance = CGSize.zero
            var value = glyph.glyph
            CTFontGetAdvancesForGlyphs(glyph.font, .horizontal, &value, &advance, 1)
            left = min(left, glyph.position.x)
            right = max(right, glyph.position.x + max(advance.width, 0.5))
            guard !glyph.isColor else { continue }
            var place = CGAffineTransform(translationX: glyph.position.x, y: glyph.position.y)
            if let path = CTFontCreatePathForGlyph(glyph.font, glyph.glyph, &place) { outline.addPath(path) }
        }
        let bounds = CGRect(x: left, y: line.baseline - line.descent, width: right - left, height: line.ascent + line.descent)
        return Piece(
            index: index, line: raw.line, word: word, range: raw.range, glyphs: glyphs,
            outline: outline.isEmpty ? outline : outline.normalized(using: .winding), bounds: bounds, baseline: line.baseline
        )
    }

    // MARK: - Pieces

    fileprivate static func isWhitespace(_ unit: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(unit) else { return false }
        return scalar.properties.isWhitespace
    }

    /// For each UTF-16 position, the grapheme it belongs to (the start of the cluster), so a letter with its accents, an
    /// emoji with its modifiers, a flag, are one piece.
    private static func clusterStarts(of text: NSString) -> [Int] {
        var starts = [Int](repeating: -1, count: text.length)
        var location = 0
        while location < text.length {
            let range = text.rangeOfComposedCharacterSequence(at: location)
            for index in range.location..<min(NSMaxRange(range), text.length) { starts[index] = range.location }
            location = max(NSMaxRange(range), location + 1)
        }
        return starts
    }

    /// For each UTF-16 position, the word it belongs to (counted from 0, spaces apart); -1 for spaces. Japanese, Chinese and
    /// Thai put no space between words: there the language's own word breaks cut them (`wordBreaks`), so a word moves as a word
    /// there too, never the whole line as one.
    private static func wordIndices(of text: NSString) -> [Int] {
        let breaks = writesWithoutSpaces(text) ? wordBreaks(in: text) : []
        var indices = [Int](repeating: -1, count: text.length)
        var word = -1
        var inWord = false
        for index in 0..<text.length {
            if isWhitespace(text.character(at: index)) {
                inWord = false
                continue
            }
            if !inWord || breaks.contains(index) {
                word += 1
                inWord = true
            }
            indices[index] = word
        }
        return indices
    }

    /// The text holds Chinese characters, kana or Thai: scripts written without spaces between words.
    private static func writesWithoutSpaces(_ text: NSString) -> Bool {
        (text as String).unicodeScalars.contains { scalar in
            WritingScript.japanese.contains(scalar) || WritingScript.thai.contains(scalar)
        }
    }

    /// Where a word starts inside a run of letters, as the language's tokenizer cuts it ("朝の習慣を" → 朝 · の · 習慣 · を).
    /// Punctuation outside a word stays with the word before it.
    private static func wordBreaks(in text: NSString) -> Set<Int> {
        let string = text as String
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = string
        var starts = Set<Int>()
        tokenizer.enumerateTokens(in: string.startIndex..<string.endIndex) { range, _ in
            starts.insert(NSRange(range, in: string).location)
            return true
        }
        return starts
    }
}
