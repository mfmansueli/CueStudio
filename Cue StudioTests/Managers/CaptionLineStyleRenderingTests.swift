//
//  CaptionLineStyleRenderingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// A caption line with a style of its own (Captions › Select): emphasized, it shows lit whole for its whole time (the word
/// said's color, or the box where the reveal boxes words); bigger, it's drawn bigger in the same place; the others stay as
/// they were. Lines saved before line styles read as plain.
@MainActor
@Suite("Caption line style rendering")
struct CaptionLineStyleRenderingTests {
    private let frame = CGSize(width: 1080, height: 1920)
    private let words = ["Sua", "ideia", "merece", "ganhar", "vida."]

    private var cue: CaptionCue {
        CaptionCue(words: words.enumerated().map { index, word in
            CaptionWord(text: word, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.4)
        })
    }

    @Test func anEmphasizedLineIsLitWholeForItsWholeTime() throws {
        var line = cue
        line.lineStyle = CaptionLineStyle(isEmphasized: true)
        let settings = CaptionSettings(theme: .educational)
        let states = CaptionCollectionRenderer.overlays([line], settings: settings, position: .bottom, frame: frame, animation: .highlight)
        #expect(states.count == 1)
        let emphasis = try #require(states.first?.lazyText?.emphasis)
        #expect(emphasis.index == 0 && emphasis.count == words.count)
        #expect(states.first?.span == line.span)
        // The lit range covers the whole line as drawn.
        let display = CaptionText.joined(words)
        #expect(emphasis.range(in: display, uppercased: false) == NSRange(location: 0, length: (display as NSString).length))
        let plain = try #require(CaptionCollectionRenderer.image(display, settings: settings, frame: frame))
        let lit = try #require(CaptionCollectionRenderer.image(display, settings: settings, frame: frame, emphasis: emphasis))
        #expect(lit.size == plain.size)
        #expect(lit.pngData() != plain.pngData())
    }

    @Test func boxedRevealBoxesTheEmphasizedLine() throws {
        var line = cue
        line.lineStyle = CaptionLineStyle(isEmphasized: true)
        let states = CaptionCollectionRenderer.overlays([line], settings: CaptionSettings(), position: .bottom, frame: frame, animation: .box)
        let emphasis = try #require(states.first?.lazyText?.emphasis)
        #expect(emphasis.style == .box(fill: .yellow, text: .black))
    }

    @Test func aBiggerLineIsDrawnBiggerAndTheOthersStay() throws {
        let settings = CaptionSettings(theme: .educational)
        var bigger = cue
        bigger.lineStyle = CaptionLineStyle(size: .biggest)
        let plain = try #require(CaptionCollectionRenderer.overlays([cue], settings: settings, position: .bottom, frame: frame).first)
        let big = try #require(CaptionCollectionRenderer.overlays([bigger], settings: settings, position: .bottom, frame: frame).first)
        #expect(big.size.height > plain.size.height)
        #expect(big.lazyText?.collection?.sizeScale ?? 0 > settings.sizeScale)
        // Never above the collection's largest size.
        var huge = settings
        huge.sizeScale = CaptionSettings.sizeRange.upperBound
        #expect(CaptionCollectionRenderer.styled(huge, for: bigger.lineStyle).clampedScale == CaptionSettings.sizeRange.upperBound)
    }

    @Test func wordEmphasisLightsARunOfWords() {
        let emphasis = WordEmphasis(words: ["a", "bc", "d"], index: 1, style: .color(.yellow), count: 2)
        #expect(emphasis.range(in: "a bc d", uppercased: false) == NSRange(location: 2, length: 4))
        #expect(WordEmphasis(words: ["a", "bc"], index: 1, style: .reveal).range(in: "a bc", uppercased: false) == NSRange(location: 2, length: 2))
        // Unspaced writing: no space between words.
        #expect(WordEmphasis.wholeLine(["東京", "へ"], style: .reveal).range(in: "東京へ", uppercased: false) == NSRange(location: 0, length: 3))
    }

    @Test func linesSavedBeforeLineStylesReadAsPlain() throws {
        let old = #"{"id":"6F8F6C0B-1E5B-4F2E-9C1B-2D7F1B0C8A11","text":"Hi","start":0,"end":1}"#
        let line = try JSONDecoder().decode(CaptionCue.self, from: Data(old.utf8))
        #expect(line.lineStyle == nil)
        let unknown = #"{"id":"6F8F6C0B-1E5B-4F2E-9C1B-2D7F1B0C8A11","text":"Hi","start":0,"end":1,"lineStyle":{"isEmphasized":true,"size":"giant"}}"#
        let future = try JSONDecoder().decode(CaptionCue.self, from: Data(unknown.utf8))
        #expect(future.lineStyle == CaptionLineStyle(isEmphasized: true, size: .regular))
        var styled = CaptionCue(text: "Hi", start: 0, end: 1)
        styled.lineStyle = CaptionLineStyle(isEmphasized: true, size: .bigger)
        let again = try JSONDecoder().decode(CaptionCue.self, from: JSONEncoder().encode(styled))
        #expect(again.lineStyle == styled.lineStyle)
    }

    @Test func splittingALineKeepsItsStyleOnBothHalves() throws {
        var line = cue
        line.lineStyle = CaptionLineStyle(isEmphasized: true)
        let (first, second) = try #require(CaptionRevision.split(line, beforeWord: 2))
        #expect(first.lineStyle == line.lineStyle && second.lineStyle == line.lineStyle)
        var typed = CaptionCue(text: "one two three", start: 0, end: 3)
        typed.lineStyle = CaptionLineStyle(size: .bigger)
        let halves = try #require(CaptionRevision.split(typed, beforeWord: 1))
        #expect(halves.1.lineStyle?.size == .bigger)
    }
}
