//
//  CaptionAnimatorTests.swift
//  Cue StudioTests
//

import CoreGraphics
import CoreImage
import Foundation
import Testing
import UIKit
@testable import Cue_Studio

/// Animated captions: what each animation draws and when, lines without word times shown whole,
/// the word being said found in the drawn line, and overlays placed where their keyframes say.
@Suite("Caption animations")
struct CaptionAnimatorTests {
    private let frame = CGSize(width: 1080, height: 1920)
    private let look = TypePreset.cue.look(for: .caption)

    private func line(_ text: String, from start: Double = 1, timed: Bool = true) -> CaptionCue {
        let words = text.split(separator: " ").enumerated().map { index, word in
            CaptionWord(text: String(word), start: start + Double(index) * 0.5, end: start + Double(index) * 0.5 + 0.4, isEstimated: !timed)
        }
        return CaptionCue(words: words)
    }

    private func overlays(_ cue: CaptionCue, _ animation: CaptionAnimation) -> [FrameOverlay] {
        CaptionAnimator.overlays(for: cue, look: look, position: .bottom, frame: frame, animation: animation)
    }

    @Test func aStillLineIsOneOverlayDrawnWhenItShows() {
        let drawn = overlays(line("one two three"), .line)
        #expect(drawn.count == 1)
        #expect(drawn[0].image == nil)
        #expect(drawn[0].lazyText != nil)
        #expect(drawn[0].fade == 0)
    }

    @Test func aFadingLineFadesAtItsEdges() {
        let drawn = overlays(line("one two three"), .fade)
        #expect(drawn.first?.fade == CaptionAnimation.fadeDuration)
    }

    @Test func groupsShowAFewWordsAtATimeBackToBack() {
        let cue = line("one two three four five")
        let drawn = overlays(cue, .groups)
        #expect(drawn.map { $0.lazyText?.text.text } == ["one two three", "four five"])
        #expect(drawn[0].span?.start == cue.start)
        #expect(drawn[0].span?.end == drawn[1].span?.start)
        #expect(drawn[1].span?.end == cue.end)
    }

    @Test func highlightDrawsOneStatePerWordAsItIsSaid() {
        let cue = line("one two three")
        let drawn = overlays(cue, .highlight)
        #expect(drawn.count == 3)
        #expect(drawn.map { $0.lazyText?.emphasis?.index } == [0, 1, 2])
        #expect(drawn[1].span?.start == cue.words[1].start)
        #expect(drawn[2].span?.end == cue.end)
        // Every state is the same line: it doesn't move from word to word.
        #expect(Set(drawn.map(\.origin.x)).count == 1)
    }

    @Test func aLineWithoutTimesOfItsOwnGetsTheEffectsOverItsWordsSharedAcrossItsTime() {
        let cue = line("one two three", timed: false)
        let drawn = overlays(cue, .box)
        #expect(drawn.count == 3)
        #expect(drawn.map { $0.lazyText?.emphasis?.index } == [0, 1, 2])
        #expect(drawn.first?.span?.start == cue.start)
        #expect(drawn.last?.span?.end == cue.end)
    }

    @Test func aLineWrittenByHandFollowsTheStyleToo() {
        let written = CaptionCue(text: "Write it  yourself ", start: 2, end: 5, origin: .manual)
        let drawn = overlays(written, .highlight)
        #expect(drawn.count == 3)
        #expect(drawn.map { $0.lazyText?.emphasis?.index } == [0, 1, 2])
        // Stray spaces from typing never keep the word from being found in the drawn line.
        #expect(drawn.allSatisfy { $0.lazyText?.text.text == "Write it yourself" })
        let words = written.lineWords
        #expect(words.first?.start == 2 && words.last?.end == 5)
        #expect(zip(words, words.dropFirst()).allSatisfy { $0.end == $1.start })
    }

    @Test func aCorrectedLineKeepsItsMeasuredTimesWhenTheyStillFitItsText() {
        let cue = line("one two three")
        #expect(cue.lineWords == cue.words)
        var typed = cue
        typed.text = "one two three "
        #expect(typed.lineWords == cue.words)
        #expect(typed.shownText == "one two three")
    }

    @Test func theWordBeingSaidIsFoundInTheDrawnLine() {
        let emphasis = WordEmphasis(words: ["Hoje", "vou", "mostrar"], index: 1, style: .color(.yellow))
        #expect(emphasis.range(in: "HOJE VOU MOSTRAR", uppercased: true) == NSRange(location: 5, length: 3))
        #expect(emphasis.range(in: "something else", uppercased: false) == nil)
        let japanese = WordEmphasis(words: ["今日", "は", "晴れ"], index: 2, style: .box(fill: .yellow, text: .black))
        #expect(japanese.range(in: "今日は晴れ", uppercased: false) == NSRange(location: 3, length: 2))
    }

    @Test func aHighlightedWordKeepsTheLinesSize() throws {
        var text = TextOverlay.caption("one two three", look: look, position: .bottom, span: TimeSpan(start: 0, end: 1))
        text.text = "one two three"
        let plain = try #require(TextOverlayRenderer.image(for: text, frameWidth: 1080))
        let boxed = try #require(TextOverlayRenderer.image(
            for: text, frameWidth: 1080, emphasis: WordEmphasis(words: ["one", "two", "three"], index: 1, style: .box(fill: .yellow, text: .black))
        ))
        #expect(plain.size == boxed.size)
    }

    @Test func anOverlayGoesWhereItsKeyframesPutIt() throws {
        let image = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 50))
        var overlay = FrameOverlay(image: image, origin: CGPoint(x: 10, y: 10), span: TimeSpan(start: 2, end: 6))
        overlay.motion = OverlayMotion([OverlayKeyframe(time: 0, center: OverlayPoint(x: 0.5, y: 0.5), scale: 2, opacity: 1)])
        overlay.frameSize = CGSize(width: 1000, height: 1000)
        let placed = try #require(overlay.placed(at: 3, cache: OverlayImageCache()))
        #expect(abs(placed.extent.midX - 500) < 0.5)
        #expect(abs(placed.extent.midY - 500) < 0.5)
        #expect(abs(placed.extent.width - 200) < 0.5)
    }
}
