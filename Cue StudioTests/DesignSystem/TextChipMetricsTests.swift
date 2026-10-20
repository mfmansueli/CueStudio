//
//  TextChipMetricsTests.swift
//  Cue StudioTests
//

import Testing
import UIKit
@testable import Cue_Studio

@Suite("TextChipMetrics")
struct TextChipMetricsTests {
    @Test func theChipScalesWithTheText() {
        let small = TextChipMetrics(textSize: 17)
        let large = TextChipMetrics(textSize: 22)
        #expect(small.fontSize < large.fontSize)
        #expect(small.height < large.height)
        #expect(TextChipMetrics(textSize: 19).fontSize > 13 && TextChipMetrics(textSize: 19).fontSize < 14.5)
        #expect(large.cornerRadius <= 8)
    }

    /// The chip's capitals sit centred on the line's: raised, never lowered, and the chip fits in the page's 6 pt line spacing.
    @Test func theChipSitsOnTheLine() {
        let metrics = TextChipMetrics(textSize: 19)
        #expect(metrics.baselineOffset > 0)
        let body = UIFont.systemFont(ofSize: 19)
        let chip = metrics.chipRect(from: 0, to: 40, baseline: 100)
        #expect(chip.minY >= 100 - body.ascender - 3)
        #expect(chip.maxY <= 100 - body.descender + 3)
    }

    /// The kern on the hidden bracket leaves room for the symbol, and for a wide one (the tortoise) its own width.
    @Test func theSymbolHasRoomBeforeTheWords() {
        let metrics = TextChipMetrics(textSize: 19)
        #expect(metrics.leadingSpace(symbol: "pause.fill") > metrics.leadingSpace(symbol: nil))
        #expect(metrics.leadingSpace(symbol: "tortoise") > metrics.leadingSpace(symbol: "pause.fill"))
        let chip = metrics.chipRect(from: 0, to: 80, baseline: 20)
        let centre = metrics.symbolCentre("tortoise", in: chip)
        #expect(centre.x - metrics.symbolWidth("tortoise") / 2 >= metrics.inset - 0.5)
    }
}
