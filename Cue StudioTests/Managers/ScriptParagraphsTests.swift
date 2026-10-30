//
//  ScriptParagraphsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the AI wrote, in paragraphs: a block of a minute and a half (the owner's script of 29/10/2026 came as one, 228 words) is cut at its
/// sentences, short paragraphs stay, a blank line goes between them, and no word, cue or number changes.
@Suite("Script paragraphs")
struct ScriptParagraphsTests {
    /// 19 sentences of 12 words: 228 words in one block.
    private let block = (1...19).map { "Morning number \($0) taught me that small habits change the whole day." }.joined(separator: " ")

    private func words(_ text: String) -> [Substring] { text.split(whereSeparator: \.isWhitespace) }

    @Test func aBlockOfAMinuteAndAHalfComesInShortParagraphs() {
        let arranged = ScriptParagraphs.arranged(block)
        let paragraphs = arranged.components(separatedBy: "\n\n")
        #expect(paragraphs.count >= 4)
        for paragraph in paragraphs {
            #expect(ReadTime.wordCount(in: paragraph) <= ScriptParagraphs.longest + ScriptParagraphs.shortest, "\(paragraph)")
            #expect(ReadTime.wordCount(in: paragraph) >= ScriptParagraphs.shortest, "\(paragraph)")
            #expect(paragraph.hasPrefix("Morning number") && paragraph.hasSuffix("day."))
        }
        #expect(words(arranged) == words(block))
    }

    @Test func shortParagraphsStayAsTheyAre() {
        let text = "I tried the five AM club.\n\nIt lasted a week.\n\nHere is what stayed."
        #expect(ScriptParagraphs.arranged(text) == text)
    }

    @Test func aParagraphOnItsOwnLineGetsABlankLineBeforeTheNext() {
        #expect(ScriptParagraphs.arranged("First line.\nSecond line.\n\n\n\nThird line.") == "First line.\n\nSecond line.\n\nThird line.")
    }

    /// A cue right after a sentence ("[pause]") stays with it, where it was written, and never opens the next paragraph.
    @Test func aCueStaysWithItsSentence() {
        let text = (1...19).map { "Morning number \($0) taught me that small habits change the whole day. [pause]" }.joined(separator: " ")
        let paragraphs = ScriptParagraphs.arranged(text).components(separatedBy: "\n\n")
        #expect(paragraphs.count >= 4)
        for paragraph in paragraphs {
            #expect(!paragraph.hasPrefix("["), "\(paragraph)")
            #expect(paragraph.hasSuffix("[pause]"), "\(paragraph)")
        }
        #expect(words(ScriptParagraphs.arranged(text)) == words(text))
    }

    @Test func aNumberWithADecimalPointIsNeverCut() {
        let text = (1...19).map { "Coffee number \($0) costs 3.5 dollars and gives me the energy I need." }.joined(separator: " ")
        let arranged = ScriptParagraphs.arranged(text)
        #expect(!arranged.contains("3.\n") && !arranged.contains("\n5 dollars"))
        #expect(words(arranged) == words(text))
    }

    /// A language written without spaces is cut at its own full stops, and no space is added.
    @Test func japaneseIsCutAtItsFullStopsWithoutSpaces() {
        let sentence = "今日は朝早く起きて、窓を開けて、ゆっくりと深呼吸をしてから、短い散歩に出かけました。"
        let text = String(repeating: sentence, count: 12)
        let arranged = ScriptParagraphs.arranged(text)
        #expect(arranged.components(separatedBy: "\n\n").count >= 2)
        #expect(arranged.replacingOccurrences(of: "\n\n", with: "") == text)
    }
}
