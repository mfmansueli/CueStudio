//
//  CaptionBlockingTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Caption formats cut the same words into blocks measured in the style's own type: a short phrase on one line when it can and
/// two at most, two lines never three, one word at a time only on measured times; sentences and long pauses end blocks, a word
/// that leans on the next never ends one when it can help it, a word wider than the room stands alone; what the creator cut by
/// hand, corrected or marked stays.
@MainActor
@Suite("Caption formats")
struct CaptionBlockingTests {
    private static let frame = CaptionBlocking.frame(widthOverHeight: 9.0 / 16.0)
    private static let settings = CaptionSettings(theme: .cue)

    /// A line of `text`, its words `step` seconds apart (each said for 80% of it), from `start`.
    private func line(_ text: String, from start: TimeInterval = 0, step: TimeInterval = 0.35, estimated: Bool = false) -> CaptionCue {
        let words = CaptionText.words(in: text).enumerated().map { index, word in
            CaptionWord(text: word, start: start + Double(index) * step, end: start + Double(index) * step + step * 0.8, isEstimated: estimated)
        }
        return CaptionCue(words: words)
    }

    private func blocks(_ lines: [CaptionCue], _ format: CaptionFormat, settings: CaptionSettings = Self.settings) -> [CaptionCue] {
        CaptionBlocking.blocks(lines, format: format, settings: settings, frame: Self.frame)
    }

    private func lineCount(_ cue: CaptionCue, settings: CaptionSettings = Self.settings) -> Int {
        CaptionCollectionRenderer.measure(cue.text, settings: settings, frame: Self.frame)?.lines ?? 0
    }

    private static let speech = "So today I want to show you the three habits that changed my mornings and how you can start them "
        + "tomorrow without buying anything at all because the first one is simply drinking a big glass of water"

    @Test func everyWordStaysInOrderInEveryFormat() {
        let made = [line(Self.speech)]
        for format in CaptionFormat.allCases {
            let cut = blocks(made, format)
            #expect(CaptionText.joined(cut.flatMap(\.words).map(\.text)) == made[0].text, "\(format)")
            #expect(zip(cut, cut.dropFirst()).allSatisfy { $0.end <= $1.start + 0.000_1 }, "\(format) overlaps")
        }
    }

    @Test func aShortPhraseTakesOneLineOnceItSaysSomething() {
        let cut = blocks([line(Self.speech)], .phrase)
        #expect(cut.count > 3)
        for block in cut {
            let lines = lineCount(block)
            #expect(lines <= 2, "\(block.text)")
            if block.words.count >= 3 { #expect(lines == 1, "\(block.text)") }
        }
    }

    @Test func twoLinesNeverTakeAThird() {
        let cut = blocks([line(Self.speech, step: 0.2)], .twoLines)
        #expect(cut.allSatisfy { lineCount($0) <= 2 })
        #expect(cut.contains { lineCount($0) == 2 })
        // Bigger type, fewer words a block, still two lines at most.
        var big = Self.settings
        big.sizeScale = 1.6
        #expect(blocks([line(Self.speech, step: 0.2)], .twoLines, settings: big).allSatisfy { lineCount($0, settings: big) <= 2 })
    }

    @Test func aSentenceAndALongPauseEndABlock() {
        var said = line("We start here. Then we go on", step: 0.3)
        // A long silence after "go".
        said.words[6].start += 1
        said.words[6].end += 1
        let cut = blocks([CaptionCue(words: said.words)], .twoLines)
        #expect(cut.map(\.text) == ["We start here.", "Then we go", "on"])
    }

    @Test func aBlockNeverEndsOnAWordThatLeansOnTheNext() {
        let cut = blocks([line(Self.speech, step: 0.2)], .phrase)
        for block in cut.dropLast() {
            #expect(!CaptionBlocking.leansOnNext(block.words.last?.text ?? ""), "\(block.text)")
        }
    }

    @Test func oneWordShowsEachMeasuredWordUntilTheNext() {
        let cut = blocks([line("Three habits that changed everything")], .oneWord)
        #expect(cut.map(\.text) == ["Three", "habits", "that", "changed", "everything"])
        for (block, next) in zip(cut, cut.dropFirst()) {
            #expect(abs(block.end - next.start) < 0.000_1)
        }
    }

    /// Words whose times are a guess (typed, or one stretch the recognizer timed as a whole) never light one by one.
    @Test func oneWordNeverPretendsOnGuessedTimes() {
        let cut = blocks([line("Three habits that changed everything for me", estimated: true)], .oneWord)
        #expect(cut.contains { $0.words.count > 1 })
    }

    @Test func aWordWiderThanTheRoomStandsAlone() {
        let long = "Pneumonoultramicroscopicsilicovolcanoconiosis"
        var big = Self.settings
        big.sizeScale = 1.6
        let cut = blocks([line("This is \(long) and more")], .phrase, settings: big)
        #expect(cut.contains { $0.text == long })
    }

    @Test func languagesWithoutSpacesAreCutByWidth() {
        let japanese = "今日は朝の習慣を三つ紹介しますそれは水を飲むことと散歩をすることと日記を書くことです"
        let made = [line(japanese, step: 0.25)]
        let cut = blocks(made, .phrase)
        #expect(cut.count > 1)
        #expect(cut.map(\.text).joined() == made[0].text)
        #expect(cut.allSatisfy { lineCount($0) <= 2 })
    }

    @Test func rightToLeftLinesKeepTheirWords() {
        let arabic = "اليوم سأريكم ثلاث عادات غيرت صباحي وكيف يمكنكم البدء بها غدا دون شراء أي شيء على الإطلاق"
        let made = [line(arabic)]
        let cut = blocks(made, .phrase)
        #expect(CaptionText.joined(cut.flatMap(\.words).map(\.text)) == made[0].text)
        #expect(cut.allSatisfy { lineCount($0) <= 2 })
    }

    @Test func linesCutByHandStayAsTheyAre() {
        var kept = line("A line the creator split by hand and wants this way", from: 20)
        kept.keepsBlock = true
        let cut = blocks([line(Self.speech), kept], .phrase)
        #expect(cut.last == kept)
    }

    @Test func correctionsAndTheirMarksSurvive() {
        var corrected = line("Massa fina muito recheio e caldo de cana do lado")
        corrected.text = "Massa fina, muito recheio e caldo de cana do lado."
        corrected.isRevised = true
        corrected.needsTimingReview = true
        let cut = blocks([corrected], .phrase)
        #expect(CaptionText.joined(cut.map(\.text)) == corrected.text)
        #expect(cut.allSatisfy { $0.isRevised && $0.needsTimingReview })
    }

    @Test func cuttingAgainTheSameWayChangesNothing() {
        let once = blocks([line(Self.speech)], .phrase)
        #expect(blocks(once, .phrase) == once)
    }

    @Test func anotherRecordingsLinesNeverMixWithTheTakes() {
        var other = line("Words from another recording of the montage", from: 2)
        other.sourceID = UUID()
        let cut = blocks([line("The take says this first and then more", from: 0), other], .twoLines)
        #expect(cut.allSatisfy { block in block.sourceID == nil || block.text.contains("recording") || block.text.contains("montage") })
        #expect(cut.contains { $0.sourceID == other.sourceID })
    }

    /// The renderer keeps a block of a format to the format's lines: a block that fits never shrinks.
    @Test func aBlockThatFitsIsDrawnAtItsSize() throws {
        var settings = Self.settings
        settings.format = .phrase
        let block = try #require(blocks([line(Self.speech)], .phrase).first)
        let plain = try #require(CaptionCollectionRenderer.overlays([block], settings: Self.settings, position: .bottom, frame: Self.frame).first)
        let formatted = try #require(CaptionCollectionRenderer.overlays([block], settings: settings, position: .bottom, frame: Self.frame).first)
        #expect(abs(plain.size.height - formatted.size.height) < 1)
    }

    // MARK: - Line breaks

    @Test func aLineBreakIsWrittenInTheTextAndReadBack() {
        let words = ["Three", "habits", "that", "changed", "everything"]
        let text = CaptionText.joined(words, breaks: [1])
        #expect(text == "Three habits\nthat changed everything")
        #expect(CaptionText.breaks(in: text) == [1])
        #expect(CaptionText.words(in: text) == words)
    }

    /// A line broken by hand goes on a new line there, and the word being said is still found in it.
    @Test func aBrokenLineIsDrawnOnTwoLinesWithItsWordsLit() throws {
        var broken = line("Three habits that changed everything")
        broken.text = "Three habits\nthat changed everything"
        #expect(broken.lineBreaks == [1])
        #expect(broken.shownText == broken.text)
        #expect(CaptionCollectionRenderer.measure(broken.text, settings: Self.settings, frame: Self.frame)?.lines == 2)
        let lit = WordEmphasis(words: broken.lineWords.map(\.text), index: 2, style: .color(.yellow), breaks: broken.lineBreaks)
        let range = try #require(lit.range(in: broken.shownText, uppercased: false))
        #expect((broken.shownText as NSString).substring(with: range) == "that")
        // A format leaves it as the creator broke it.
        #expect(blocks([broken], .oneWord) == [broken])
    }

    /// Return in a caption's field goes on to the next caption: only the new line just typed is Return, a line break the
    /// caption already had stays.
    @Test func returnIsOnlyTheNewLineJustTyped() {
        let stored = "Three habits\nthat changed everything"
        #expect(CaptionLineCard.withoutTypedReturn("Three habits\nthat changed\n everything", stored: stored) == stored)
        #expect(CaptionLineCard.withoutTypedReturn("Three habits that changed everything\n", stored: "Three habits that changed everything")
            == "Three habits that changed everything")
    }
}
