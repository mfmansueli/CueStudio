//
//  AutoEditZoomPickerTests.swift
//  Cue StudioTests
//

import Foundation
import NaturalLanguage
import Testing
@testable import Cue_Studio

/// Auto edit's zoom step: lines with a clear number, value or name, never two closer than the spacing, never over a zoom already
/// there.
struct AutoEditZoomPickerTests {
    private func line(_ text: String, _ start: TimeInterval) -> CaptionCue {
        CaptionCue(text: text, start: start, end: start + 2, origin: .manual)
    }

    @Test func picksLinesWithAClearValueOnly() {
        let lines = [line("We grew 40% in one year", 0), line("and then we kept going", 8), line("it cost R$ 300 a month", 16)]
        let zooms = AutoEditZoomPicker.zooms(for: lines, existing: [], strength: .medium, language: .portuguese)
        #expect(zooms.map(\.span.start) == [0, 16])
        #expect(zooms.allSatisfy { $0.strength == .medium })
    }

    @Test func keepsTheSpacingAndLeavesZoomedLines() {
        let lines = [line("We grew 40% this year", 0), line("then 60% the next", 3), line("and 80% after that", 12)]
        let existing = [PhraseZoom(span: TimeSpan(start: 12, end: 14), strength: .strong)]
        let zooms = AutoEditZoomPicker.zooms(for: lines, existing: existing, strength: .subtle, language: .english)
        #expect(zooms.map(\.span.start) == [0], "3 s after another is too close; 12 s already has the creator's")
    }
}
