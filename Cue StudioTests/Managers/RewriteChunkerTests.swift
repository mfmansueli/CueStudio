//
//  RewriteChunkerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A script is edited a part at a time (`RewriteChunker`): measured on an iPhone 15 Pro, one request for 374 words came back with 188.
@Suite("Rewrite chunker")
struct RewriteChunkerTests {
    private static func paragraph(_ index: Int, words: Int = 60) -> String {
        (0..<words).map { "word\(index)x\($0)" }.joined(separator: " ") + "."
    }

    private static func script(paragraphs: Int, words: Int = 60) -> String {
        (0..<paragraphs).map { paragraph($0, words: words) }.joined(separator: "\n\n")
    }

    @Test func aShortScriptIsOnePart() {
        let chunks = RewriteChunker.chunks(of: Self.script(paragraphs: 2, words: 30), for: .fixGrammar)
        #expect(chunks.count == 1)
        #expect(chunks[0].isRewritten)
    }

    @Test func nothingIsNoParts() {
        #expect(RewriteChunker.chunks(of: " \n\n ", for: .fixGrammar).isEmpty)
    }

    @Test func aLongScriptIsCutIntoPartsThatKeepEveryWord() {
        let text = Self.script(paragraphs: 12, words: 70)
        let chunks = RewriteChunker.chunks(of: text, for: .fixGrammar)
        #expect(chunks.count >= 4)
        #expect(chunks.reduce(0) { $0 + $1.words } == ReadTime.wordCount(in: text))
        #expect(RewriteChunker.joined(chunks.map(\.text)).replacingOccurrences(of: "\n\n", with: " ") == text.replacingOccurrences(of: "\n\n", with: " "))
    }

    @Test func noPartIsBiggerThanTheModelAnswersInFull() {
        let chunks = RewriteChunker.chunks(of: Self.script(paragraphs: 20, words: 70), for: .moreEnergy)
        #expect(chunks.allSatisfy { PromptCost.units(of: $0.text) <= RewriteChunker.partUnits + 200 })
    }

    @Test func oneHugeParagraphIsCutAtItsSentences() {
        let sentence = "This is one sentence of the long paragraph that never ends, with enough words in it to count."
        let paragraph = Array(repeating: sentence, count: 40).joined(separator: " ")
        let chunks = RewriteChunker.chunks(of: paragraph, for: .fixGrammar)
        #expect(chunks.count > 2)
        #expect(chunks.allSatisfy { $0.text.hasSuffix(".") })
        #expect(chunks.reduce(0) { $0 + $1.words } == ReadTime.wordCount(in: paragraph))
    }

    @Test func aStrongerCTAOnlyTouchesTheClosing() {
        let text = Self.script(paragraphs: 5, words: 40)
        let chunks = RewriteChunker.chunks(of: text, for: .strongerCTA)
        #expect(chunks.count == 2)
        #expect(chunks[0].isRewritten == false)
        #expect(chunks[1].isRewritten)
        #expect(chunks[1].text == Self.paragraph(4, words: 40))
        #expect(chunks[1].leadIn == Self.paragraph(3, words: 40))
        #expect(chunks[0].text == Self.script(paragraphs: 4, words: 40))
    }

    @Test func aScriptOfOneParagraphIsItsOwnClosing() {
        let chunks = RewriteChunker.chunks(of: "Follow for more.", for: .strongerCTA)
        #expect(chunks == [RewriteChunk(text: "Follow for more.")])
    }

    @Test func aScriptToBeMadeMuchLongerIsCutInSmallerParts() {
        let sentence = "Here" + (0..<13).map { " word\($0)" }.joined() + "."
        let text = Array(repeating: Array(repeating: sentence, count: 5).joined(separator: " "), count: 6).joined(separator: "\n\n")
        let same = RewriteChunker.chunks(of: text, for: .fitToTime, expansion: 1)
        let grown = RewriteChunker.chunks(of: text, for: .fitToTime, expansion: 6)
        #expect(grown.count > same.count)
    }

    @Test func partsAreJoinedByABlankLine() {
        #expect(RewriteChunker.joined(["One. ", " Two.", "", "Three."]) == "One.\n\nTwo.\n\nThree.")
    }
}
