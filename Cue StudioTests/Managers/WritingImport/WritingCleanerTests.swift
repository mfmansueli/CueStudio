//
//  WritingCleanerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the creator pastes is messy: the cleaner gives back separate texts that say only how they write.
@Suite("Import my writing · cleaning")
struct WritingCleanerTests {
    @Test func aPasteFromANotesAppBecomesSeparateTextsWithoutTheNoise() {
        let pieces = WritingCleaner.pieces(from: WritingSamples.messyPaste, source: "Pasted")
        #expect(pieces.count == 2, "the note about groceries is too short to say anything")
        let text = pieces.map(\.text).joined(separator: "\n")
        for noise in ["http", "@", "#", "[", "+1", "00:05", "Hook:", "CTA:", "Body:", "example.com"] {
            #expect(!text.contains(noise), "\(noise) should be gone")
        }
        #expect(text.contains("Mornings are hard for me."))
        #expect(text.contains("Stop scrolling for ten seconds."))
        #expect(pieces.allSatisfy { $0.source == "Pasted" && $0.language == "en" })
    }

    @Test func aShortPasteWithNoSeparatorIsOneText() {
        let pieces = WritingCleaner.pieces(from: WritingSamples.maya[0])
        #expect(pieces.count == 1)
    }

    @Test func aTextWithTooFewWordsIsLeftOut() {
        #expect(WritingCleaner.pieces(from: "Follow me for more tips today.").isEmpty)
    }

    @Test func theSameTextTwiceIsKeptOnce() {
        let raw = [WritingSamples.maya[0], WritingSamples.maya[0], WritingSamples.maya[1]].joined(separator: "\n---\n")
        #expect(WritingCleaner.pieces(from: raw).count == 2)
    }

    @Test func aLongPasteWithNoSeparatorIsCutAtBlankLines() {
        let pieces = WritingCleaner.pieces(from: WritingSamples.daniel.joined(separator: "\n\n"))
        #expect(pieces.count == WritingSamples.daniel.count)
    }

    @Test func oneSentencePerLineWithNoFullStopsBecomesSentences() {
        let raw = "Stop scrolling for a second\nI want to show you one thing\nIt took me three years to learn this\nNow it takes you ten seconds"
        let pieces = WritingCleaner.pieces(from: raw)
        #expect(pieces.first?.text == "Stop scrolling for a second. I want to show you one thing. It took me three years to learn this. Now it takes you ten seconds.")
    }

    @Test func atMostSixtyTextsAreRead() {
        let raw = (1...80).map { "Text number \($0) is about something quite different every time, so none of them repeats another one." }.joined(separator: "\n---\n")
        #expect(WritingCleaner.pieces(from: raw).count == WritingCleaner.maximumPieces)
    }

    @Test func aTextOfNothingButSymbolsIsLeftOut() {
        #expect(WritingCleaner.pieces(from: String(repeating: "12 34 56 78 ", count: 10) + "-- -- -- -- --").isEmpty)
    }
}
