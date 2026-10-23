//
//  CoverTextLayout.swift
//  Cue Studio
//

import CoreText
import UIKit

/// Where a cover's title goes, line by line, measured with Core Text so the preview, the saved cover and the tests agree. The
/// whole block is fitted, not each line: the words get smaller (down to `minimumSize`) until the longest word fits the block's
/// width, every line fits it, the block fits the height it has and it stays inside the cover around its center. Lines break
/// only between words, the way the system breaks them in each language (spaces, or a dictionary in Japanese, Chinese and
/// Thai), so a word is never cut, and right-to-left titles are aligned from their own side. Emoji and accents are measured
/// like any other glyph.
nonisolated struct CoverTextLayout {
    /// Smallest the words get, as a share of the cover's width.
    static let minimumSize = 0.034
    /// Most lines a title takes.
    static let maximumLines = 6
    /// How far the block (and its box) keeps from the cover's edges, as a share of its width.
    static let edgeMargin = 0.045

    struct Line {
        let line: CTLine
        /// The line's box (top left, cover points): its full height and the width of its glyphs.
        let frame: CGRect
        /// Where the line's text starts in the title's display string (UTF-16).
        let range: NSRange
        /// The baseline, from the top of `frame`.
        let baseline: CGFloat
    }

    /// The title as drawn (capitals when asked; without the number in a list), with its font.
    let text: NSAttributedString
    let font: UIFont
    let lines: [Line]
    /// The block of lines (top left, cover points), the kicker and the number not included.
    let block: CGRect
    /// The highlighted words' ranges in `text` (UTF-16).
    let highlightRanges: [NSRange]
    /// The rectangles behind each highlighted word (a word on two lines never happens: lines break between words).
    let highlightRects: [CGRect]
    /// The big number of a list cover, and where.
    let number: (text: NSAttributedString, frame: CGRect)?
    /// The kicker's text and its pill.
    let kicker: (text: NSAttributedString, frame: CGRect)?
    /// The words couldn't fit even at the smallest size: Cover Studio says to shorten the title.
    let overflows: Bool
    let isRightToLeft: Bool

    /// Everything drawn for the title: number, kicker, block and highlights.
    var bounds: CGRect {
        var union = block
        for rect in highlightRects { union = union.union(rect) }
        if let number { union = union.union(number.frame) }
        if let kicker { union = union.union(kicker.frame) }
        return union
    }

    // MARK: - Laying out

    /// `avoid`: what the words must stay clear of (the cover's tags and handle, a before/after's labels); a block whose center
    /// is inside one of them was put there on purpose and only avoids the others.
    static func layout(title: String, style raw: CoverTitleStyle, coverSize size: CGSize, avoid: [CGRect] = []) -> CoverTextLayout {
        let style = raw.clamped
        let width = size.width, height = size.height
        let display = style.uppercase ? title.localizedUppercase : title
        // A list's number goes big over the rest.
        var body = display
        var numberText: String?
        var highlights = style.highlights
        if style.showsNumber, let number = CoverWords.firstNumber(in: display), let range = display.range(of: number) {
            numberText = number
            let numberIndex = CoverWords.ranges(in: display).firstIndex { display[$0] == Substring(number) } ?? 0
            body = (String(display[..<range.lowerBound]) + String(display[range.upperBound...]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            highlights = Set(style.highlights.compactMap { $0 == numberIndex ? nil : ($0 > numberIndex ? $0 - 1 : $0) })
        }
        let rightToLeft = Self.isRightToLeft(body.isEmpty ? display : body)
        let center = CGPoint(x: style.center.x * width, y: style.center.y * height)
        let margin = width * edgeMargin
        // Room around the center, so the block never leaves the cover.
        let roomWidth = max(width * 0.2, 2 * min(center.x, width - center.x) - margin * 2)
        let maxWidth = min(style.width * width, roomWidth)
        let roomHeight = max(height * 0.1, 2 * min(center.y, height - center.y) - margin * 2)

        var fontSize = style.size * width
        let smallest = minimumSize * width
        let obstacles = avoid.filter { !$0.contains(center) }
        var result: CoverTextLayout?
        for _ in 0..<40 {
            let attempt = Attempt.make(
                body: body, number: numberText, kicker: style.kicker, style: style, fontSize: fontSize, maxWidth: maxWidth, coverWidth: width
            )
            let atSmallest = fontSize <= smallest + 0.01
            let fits = attempt.longestWord <= maxWidth && attempt.lineCount <= maximumLines && attempt.totalHeight <= roomHeight
            let placed = attempt.placed(
                center: center, style: style, highlights: highlights, maxWidth: maxWidth, rightToLeft: rightToLeft, overflows: !fits && atSmallest
            )
            result = placed
            let clear = !obstacles.contains { $0.intersects(placed.bounds) }
            if (fits && clear) || atSmallest { break }
            fontSize = max(smallest, fontSize * 0.93)
        }
        return result ?? Attempt.make(
            body: body, number: numberText, kicker: style.kicker, style: style, fontSize: fontSize, maxWidth: maxWidth, coverWidth: width
        ).placed(center: center, style: style, highlights: highlights, maxWidth: maxWidth, rightToLeft: rightToLeft, overflows: true)
    }

    /// Bold faces of the system's fonts for scripts the cover fonts lack: Thai, Japanese, Chinese, Korean, Arabic, Hindi.
    private static let boldFallbacks = [
        "Thonburi-Bold", "HiraginoSans-W7", "PingFangSC-Semibold", "PingFangTC-Semibold", "AppleSDGothicNeo-Bold", "GeezaPro-Bold",
        "KohinoorDevanagari-Semibold",
    ]

    /// Whether the first letter with a direction is written right to left (Arabic, Hebrew, …).
    static func isRightToLeft(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF: return true
            default:
                if CharacterSet.letters.contains(scalar) { return false }
            }
        }
        return false
    }

    /// The typeface of a cover's words at `size`. Letters it lacks (Arabic, Thai, Japanese, Chinese, Hindi…) come from the
    /// system's heavy type first, so a title in another script is as bold as the template; emoji come from the system's.
    static func font(_ font: CoverFont, size: CGFloat) -> UIFont {
        let base = CoverDesignRenderer.words(font, size: size)
        let heavy = UIFont.systemFont(ofSize: size, weight: font.isSerif ? .semibold : .heavy).fontDescriptor
        // The system's own fallbacks are regular weight for some scripts (Thai): their bold faces come first.
        let bold = boldFallbacks.map { UIFontDescriptor(name: $0, size: size) }
        let descriptor = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontCascadeListAttribute as String): [heavy] + bold,
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// The words as measured for one font size.
    private struct Attempt {
        var text = NSAttributedString()
        var font = UIFont.systemFont(ofSize: 12)
        var ranges: [NSRange] = []
        var lineCount = 0
        var lineHeight: CGFloat = 0
        var longestWord: CGFloat = 0
        var totalHeight: CGFloat = 0
        var numberText: NSAttributedString?
        var numberSize: CGSize = .zero
        var kickerText: NSAttributedString?
        var kickerSize: CGSize = .zero
        var gap: CGFloat = 0

        static func make(
            body: String, number: String?, kicker: String, style: CoverTitleStyle, fontSize: CGFloat, maxWidth: CGFloat, coverWidth: CGFloat
        ) -> Attempt {
            var attempt = Attempt()
            let font = CoverTextLayout.font(style.font, size: fontSize)
            attempt.font = font
            attempt.text = NSAttributedString(string: body, attributes: [.font: font, .ligature: 1])
            // Room for a highlight's box on both sides of the longest word.
            let pad = style.highlightStyle == .box && !style.highlights.isEmpty ? fontSize * 0.36 : 0
            let words = CoverWords.ranges(in: body)
            attempt.longestWord = words.map { range in
                Self.width(of: NSAttributedString(string: String(body[range]), attributes: [.font: font])) + pad
            }.max() ?? 0
            attempt.ranges = Self.breakLines(attempt.text, width: maxWidth - pad)
            attempt.lineCount = attempt.ranges.count
            attempt.lineHeight = (font.ascender - font.descender) * Self.lineSpacing(style.font)
            var total = attempt.lineHeight * CGFloat(attempt.lineCount)
            attempt.gap = fontSize * 0.16
            if let number {
                let numberFont = CoverTextLayout.font(style.font, size: min(fontSize * 2.6, coverWidth * 0.42))
                let text = NSAttributedString(string: number, attributes: [.font: numberFont])
                attempt.numberText = text
                attempt.numberSize = CGSize(width: Self.width(of: text), height: (numberFont.ascender - numberFont.descender) * 0.86)
                total += attempt.numberSize.height + attempt.gap
            }
            if !kicker.isEmpty {
                let kickerFont = UIFont.systemFont(ofSize: max(coverWidth * 0.032, fontSize * 0.34), weight: .heavy)
                let shown = TextShaping.uppercased(kicker)
                var attributes: [NSAttributedString.Key: Any] = [.font: kickerFont]
                if TextShaping.allowsLetterSpacing(in: shown) { attributes[.kern] = kickerFont.pointSize * 0.06 }
                let text = NSAttributedString(string: shown, attributes: attributes)
                attempt.kickerText = text
                attempt.kickerSize = CGSize(
                    width: Self.width(of: text) + kickerFont.pointSize * 1.1, height: (kickerFont.ascender - kickerFont.descender) * 1.45
                )
                total += attempt.kickerSize.height + attempt.gap
            }
            attempt.totalHeight = total + (style.background == .box ? fontSize * 0.5 : 0)
            return attempt
        }

        /// Condensed type sits tighter.
        static func lineSpacing(_ font: CoverFont) -> CGFloat {
            font.isCondensed ? 0.9 : 1.02
        }

        static func width(of text: NSAttributedString) -> CGFloat {
            CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(text), nil, nil, nil))
        }

        /// The lines `text` takes at `width`, broken only where a word starts (the system's word breaking for each language:
        /// spaces, or a dictionary in Japanese, Chinese and Thai), so a word is never cut; what follows a word (a space, a
        /// comma, "、") stays on its line. A word wider than a line has a line to itself (the fit then makes the title smaller).
        static func breakLines(_ text: NSAttributedString, width: CGFloat) -> [NSRange] {
            let string = text.string
            guard text.length > 0 else { return [] }
            let starts = CoverWords.ranges(in: string).map { NSRange($0, in: string).location }.filter { $0 > 0 }
            guard !starts.isEmpty else { return [NSRange(location: 0, length: text.length)] }
            let nsString = string as NSString
            func fits(_ range: NSRange) -> Bool {
                Self.width(of: text.attributedSubstring(from: trimmingTrailingSpace(range, in: nsString))) <= width
            }
            var ranges: [NSRange] = []
            var lineStart = 0
            var breaks = starts[...]
            while lineStart < text.length {
                // The last word start after which this line still fits.
                var end = text.length
                var candidate: Int?
                for start in breaks where start > lineStart {
                    if fits(NSRange(location: lineStart, length: start - lineStart)) { candidate = start } else { break }
                }
                if fits(NSRange(location: lineStart, length: text.length - lineStart)) {
                    end = text.length
                } else if let candidate {
                    end = candidate
                } else {
                    // Not even one word fits: it takes the line alone.
                    end = breaks.first { $0 > lineStart } ?? text.length
                }
                ranges.append(NSRange(location: lineStart, length: end - lineStart))
                lineStart = end
                breaks = breaks.drop { $0 <= lineStart }
            }
            return ranges
        }

        func placed(
            center: CGPoint, style: CoverTitleStyle, highlights: Set<Int>, maxWidth: CGFloat, rightToLeft: Bool, overflows: Bool
        ) -> CoverTextLayout {
            let string = text.string as NSString
            let lines: [(line: CTLine, range: NSRange, width: CGFloat)] = ranges.map { range in
                let trimmed = Self.trimmingTrailingSpace(range, in: string)
                let line = CTLineCreateWithAttributedString(text.attributedSubstring(from: trimmed))
                return (line, trimmed, CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
            }
            let blockWidth = lines.map(\.width).max() ?? 0
            let linesHeight = lineHeight * CGFloat(lines.count)
            let boxPad = style.background == .box ? font.pointSize * 0.25 : 0
            let top = center.y - totalHeight / 2 + boxPad
            var y = top
            // The block's left edge: its alignment, read from the title's own side.
            let alignment = Self.resolved(style.alignment, rightToLeft: rightToLeft)
            let blockX: CGFloat = switch alignment {
            case .leading: center.x - maxWidth / 2
            case .trailing: center.x + maxWidth / 2 - blockWidth
            case .center: center.x - blockWidth / 2
            }
            var kicker: (text: NSAttributedString, frame: CGRect)?
            if let kickerText {
                let x: CGFloat = switch alignment {
                case .leading: blockX
                case .trailing: blockX + blockWidth - kickerSize.width
                case .center: center.x - kickerSize.width / 2
                }
                kicker = (kickerText, CGRect(x: x, y: y, width: kickerSize.width, height: kickerSize.height))
                y += kickerSize.height + gap
            }
            var number: (text: NSAttributedString, frame: CGRect)?
            if let numberText {
                let x: CGFloat = switch alignment {
                case .leading: blockX
                case .trailing: blockX + blockWidth - numberSize.width
                case .center: center.x - numberSize.width / 2
                }
                number = (numberText, CGRect(x: x, y: y, width: numberSize.width, height: numberSize.height))
                y += numberSize.height + gap
            }
            let ascent = font.ascender * Self.lineSpacing(style.font)
            var placed: [Line] = []
            for entry in lines {
                let x: CGFloat = switch alignment {
                case .leading: blockX
                case .trailing: blockX + blockWidth - entry.width
                case .center: center.x - entry.width / 2
                }
                placed.append(Line(line: entry.line, frame: CGRect(x: x, y: y, width: entry.width, height: lineHeight), range: entry.range, baseline: ascent))
                y += lineHeight
            }
            let block = CGRect(x: blockX, y: top + (kicker.map { $0.frame.height + gap } ?? 0) + (number.map { $0.frame.height + gap } ?? 0),
                               width: blockWidth, height: linesHeight)
            let words = CoverWords.ranges(in: string as String).map { NSRange($0, in: string as String) }
            let ranges = highlights.sorted().compactMap { words.indices.contains($0) ? words[$0] : nil }
            return CoverTextLayout(
                text: text, font: font, lines: placed, block: block, highlightRanges: ranges,
                highlightRects: Self.highlightRects(ranges, lines: placed, in: string, style: style, font: font),
                number: number, kicker: kicker, overflows: overflows, isRightToLeft: rightToLeft
            )
        }

        static func resolved(_ alignment: LineAlignment, rightToLeft: Bool) -> LineAlignment {
            guard rightToLeft else { return alignment }
            switch alignment {
            case .leading: return .trailing
            case .trailing: return .leading
            case .center: return .center
            }
        }

        static func trimmingTrailingSpace(_ range: NSRange, in string: NSString) -> NSRange {
            var length = range.length
            while length > 0, let scalar = UnicodeScalar(string.character(at: range.location + length - 1)),
                  CharacterSet.whitespacesAndNewlines.contains(scalar) {
                length -= 1
            }
            return NSRange(location: range.location, length: length)
        }

        /// A rectangle behind each highlighted word, from where its glyphs start to where they end on its line (either way
        /// round for right-to-left lines).
        static func highlightRects(_ words: [NSRange], lines: [Line], in string: NSString, style: CoverTitleStyle, font: UIFont) -> [CGRect] {
            var rects: [CGRect] = []
            func isSpace(at index: Int) -> Bool {
                guard index >= 0, index < string.length, let scalar = UnicodeScalar(string.character(at: index)) else { return true }
                return CharacterSet.whitespacesAndNewlines.contains(scalar)
            }
            for word in words {
                // A box reaches past its word only where there's a space: in Thai or Japanese the next letter is right there.
                let roomy = isSpace(at: word.location - 1) && isSpace(at: word.location + word.length)
                let pad = style.highlightStyle == .box ? font.pointSize * (roomy ? 0.16 : 0.03) : 0
                for line in lines {
                    let overlap = NSIntersectionRange(word, line.range)
                    guard overlap.length > 0 else { continue }
                    // The line was made from its own part of the string: its indices start at 0.
                    let local = overlap.location - line.range.location
                    let from = CTLineGetOffsetForStringIndex(line.line, local, nil)
                    let to = CTLineGetOffsetForStringIndex(line.line, local + overlap.length, nil)
                    let start = min(from, to), end = max(from, to)
                    rects.append(CGRect(
                        x: line.frame.minX + start - pad, y: line.frame.minY + line.frame.height * 0.04,
                        width: end - start + pad * 2, height: line.frame.height * 0.94
                    ))
                }
            }
            return rects
        }
    }
}
