//
//  CoverTextLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// A cover's title fitted as a block: a long title gets smaller instead of leaving the cover, a word is never cut between
/// lines in any language, right-to-left titles start from their side, and highlights land on whole words.
@Suite("Cover text layout")
struct CoverTextLayoutTests {
    private let size = CGSize(width: 1080, height: 1920)

    private func layout(_ title: String, _ configure: (inout CoverTitleStyle) -> Void = { _ in }) -> CoverTextLayout {
        var style = CoverComposition.make(.opinion, title: title).title
        configure(&style)
        return CoverTextLayout.layout(title: title, style: style, coverSize: size)
    }

    /// Every line ends at the end of a word of the title (or the title's end).
    private func breaksBetweenWords(_ layout: CoverTextLayout) -> Bool {
        let string = layout.text.string
        let words = CoverWords.ranges(in: string).map { NSRange($0, in: string) }
        return layout.lines.dropLast().allSatisfy { line in
            let end = line.range.location + line.range.length
            return !words.contains { $0.location < end && end < $0.location + $0.length }
        }
    }

    private func inside(_ rect: CGRect) -> Bool {
        let cover = CGRect(origin: .zero, size: size).insetBy(dx: size.width * 0.02, dy: size.width * 0.02)
        return cover.contains(rect)
    }

    @Test func aShortTitleKeepsItsSize() {
        let fitted = layout("Real talk")
        #expect(abs(fitted.font.pointSize - 0.16 * size.width) < 1)
        #expect(fitted.lines.count == 1)
        #expect(!fitted.overflows)
    }

    @Test func aLongTitleShrinksAndStaysOnTheCover() {
        let title = "Nobody tells you this about moving to another country alone at thirty and starting over from nothing"
        let fitted = layout(title)
        #expect(fitted.font.pointSize < 0.16 * size.width)
        #expect(fitted.lines.count <= CoverTextLayout.maximumLines)
        #expect(inside(fitted.bounds))
        #expect(breaksBetweenWords(fitted))
        #expect(!fitted.overflows)
    }

    @Test func aBlockNearTheEdgeIsKeptInsideAroundItsCenter() {
        let fitted = layout("Three things I wish I knew before") { $0.center = OverlayPoint(x: 0.5, y: 0.08) }
        #expect(inside(fitted.bounds))
        let left = layout("A title pushed to the left side") { $0.center = OverlayPoint(x: 0.2, y: 0.5) }
        #expect(inside(left.bounds))
    }

    @Test func aWordTooLongForALineShrinksTheWholeTitle() {
        let fitted = layout("Supercalifragilisticexpialidocious")
        #expect(fitted.lines.count == 1)
        #expect(fitted.block.width <= 0.9 * size.width + 1)
    }

    @Test func accentsEmojiAndCapitalsInEveryLanguage() {
        let portuguese = layout("Coração de São Paulo 🇧🇷")
        #expect(portuguese.text.string == "CORAÇÃO DE SÃO PAULO 🇧🇷")
        #expect(inside(portuguese.bounds))
        let german = layout("Straße")
        #expect(german.text.string == "STRASSE")
    }

    @Test func thaiAndJapaneseBreakBetweenWords() {
        for title in ["วิธีทำกาแฟให้อร่อยที่บ้านแบบง่ายๆ สำหรับมือใหม่", "朝の習慣を変えたら人生が変わった三つの理由を話します"] {
            let fitted = layout(title) { $0.uppercase = false }
            #expect(fitted.lines.count > 1, "\(title) should take more than one line")
            #expect(breaksBetweenWords(fitted), "\(title) broke inside a word")
            #expect(inside(fitted.bounds))
        }
    }

    @Test func rightToLeftTitlesStartFromTheirSide() {
        let fitted = layout("ثلاث عادات صباحية غيرت حياتي تماما") { style in
            style.alignment = .leading
            style.uppercase = false
            style.center = OverlayPoint(x: 0.5, y: 0.5)
        }
        #expect(fitted.isRightToLeft)
        // Leading is the right edge in Arabic: every line ends on the block's right.
        let right = fitted.lines.map(\.frame.maxX)
        #expect(right.allSatisfy { abs($0 - (right.max() ?? 0)) < 1 })
        #expect(!layout("Hello").isRightToLeft)
    }

    @Test func highlightsAreWholeWords() {
        let title = "Three morning habits"
        let fitted = layout(title) { style in
            style.highlights = [1]
            style.highlightStyle = .box
        }
        #expect(fitted.highlightRanges == [NSRange(location: 6, length: 7)])
        #expect(fitted.highlightRects.count == 1)
        #expect(fitted.highlightRects[0].width > 0)
    }

    @Test func aListDrawsItsNumberBigAndTheRestUnder() {
        let fitted = CoverTextLayout.layout(
            title: "5 foods in São Paulo", style: CoverComposition.make(.list, title: "5 foods in São Paulo").title, coverSize: size
        )
        #expect(fitted.number?.text.string == "5")
        #expect(fitted.text.string == "FOODS IN SÃO PAULO")
        #expect((fitted.number?.frame.maxY ?? .infinity) <= fitted.block.minY)
    }

    @Test func theKeyWordIsTheLongest() {
        #expect(CoverWords.keyWord(in: "3 morning habits that work") == 1)
        #expect(CoverWords.keyWord(in: "Hello") == nil)
        #expect(CoverWords.firstNumber(in: "Top 10 cafés") == "10")
    }
}
