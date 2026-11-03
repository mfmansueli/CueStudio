//
//  NoCutLabelsLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The two layouts that keep a label whole in every language (owner, 02/11/2026): `FairShareLayout` (slots side by side) and
/// `BalancedRowsLayout` (chips on as few rows as fit).
@MainActor
struct NoCutLabelsLayoutTests {
    // MARK: - FairShareLayout

    @Test func slotsThatAllFitAShareGetEqualShares() {
        #expect(FairShareLayout.widths(ideals: [60, 90], in: 200) == [100, 100])
    }

    /// "Voz | Constante": the long word gets its own width, and what is left is shared, so neither is cut.
    @Test func aLongLabelKeepsItsWidthAndTheRestIsShared() {
        let widths = FairShareLayout.widths(ideals: [50, 120], in: 180)
        #expect(widths == [55, 125])
        #expect(widths.reduce(0, +) == 180)
    }

    @Test func pastTheirOwnWidthsTheSharesFallInProportion() {
        let widths = FairShareLayout.widths(ideals: [100, 300], in: 200)
        #expect(widths == [50, 150])
    }

    // MARK: - BalancedRowsLayout

    /// Six chips whose names fit a sixth of the row stay on one row.
    @Test func chipsThatFitStayOnOneRow() {
        let grid = BalancedRowsLayout.grid(ideals: Array(repeating: 40, count: 6), in: 320, spacing: 8)
        #expect(grid.rows == 1)
        #expect(grid.columns == 6)
    }

    /// One name too long for a sixth ("Afstandsbediening") puts the six chips on two rows of three, each wide enough for it.
    @Test func oneLongNameMakesTwoBalancedRows() {
        let grid = BalancedRowsLayout.grid(ideals: [40, 40, 40, 40, 82, 40], in: 320, spacing: 8)
        #expect(grid.rows == 2)
        #expect(grid.columns == 3)
        #expect(grid.columnWidth >= 82)
    }

    /// However long a name, a chip has the whole row before anything is cut.
    @Test func aNameLongerThanAnyRowGetsTheWholeRow() {
        let grid = BalancedRowsLayout.grid(ideals: [40, 400], in: 320, spacing: 8)
        #expect(grid.columns == 1)
        #expect(grid.rows == 2)
        #expect(grid.columnWidth == 320)
    }
}

/// `LabelLineBreak`: a long name goes on two even lines between words, never inside one (owner, 02/11/2026).
struct LabelLineBreakTests {
    @Test func aNameOfSeveralWordsBreaksBetweenThemEvenly() {
        #expect(LabelLineBreak.twoLines("Voce fuori campo") == "Voce fuori\ncampo")
        #expect(LabelLineBreak.twoLines("Dissolvenza incrociata") == "Dissolvenza\nincrociata")
    }

    /// Japanese has no spaces: the break falls between its words.
    @Test func aLanguageWithoutSpacesBreaksBetweenWords() throws {
        let lines = try #require(LabelLineBreak.twoLines("スライドするボックス"))
        #expect(lines.contains("\n"))
        #expect(lines.replacingOccurrences(of: "\n", with: "") == "スライドするボックス")
    }

    @Test func oneWordOrALineWithoutLettersDoesNotBreak() {
        #expect(LabelLineBreak.twoLines("Unschärfebereich") == nil)
        #expect(LabelLineBreak.twoLines("Clip 2") == nil)
        #expect(LabelLineBreak.twoLines("@gebruikersnaam") == nil)
    }
}
