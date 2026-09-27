//
//  ScriptWordsTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptWords")
struct ScriptWordsTests {
    /// Two paragraphs: three lines of 40 pt, then one line after 30 pt of spacing.
    private let frames: [Range<Double>] = [0..<120, 150..<190]
    private let words = ScriptWords(text: "aaaa bbbb cccc dddd eeee ffff\ngggg")

    private func offset(_ index: Int) -> Double? {
        words.offset(forWord: index, paragraphFrames: frames, lineHeight: 40, endOffset: 150)
    }

    @Test func tokensIgnoreCaseAccentsAndPunctuation() {
        #expect(ScriptWords.tokens(in: "Olá, VOCÊ! Don't stop—now.") == ["ola", "voce", "dont", "stop", "now"])
        #expect(ScriptWords.tokens(in: "It’s 10x") == ["its", "10x"])
    }

    @Test func cuesAreNotSpoken() {
        let words = ScriptWords(text: "Hey there [pause]\n[smile] Second line")
        #expect(words.tokens == ["hey", "there", "second", "line"])
        #expect(words.locations[1] == ScriptWords.Location(paragraph: 0, fraction: 4.0 / 9))
        #expect(words.locations[2] == ScriptWords.Location(paragraph: 1, fraction: 0))
    }

    @Test func firstWordSitsAtTheTop() {
        #expect(offset(0) == 0)
    }

    @Test func offsetMovesThroughAParagraphAsItIsRead() throws {
        let offsets = try (0..<6).map { try #require(offset($0)) }
        #expect(offsets == offsets.sorted())
        // The last line of a three-line paragraph ends two lines down.
        #expect(offsets[5] == 80)
    }

    @Test func singleLineParagraphSitsAtItsTop() {
        #expect(offset(6) == 150)
    }

    @Test func pastTheLastWordIsTheEnd() {
        #expect(offset(7) == 150)
    }

    @Test func unmeasuredParagraphHasNoOffset() {
        #expect(words.offset(forWord: 6, paragraphFrames: [0..<120], lineHeight: 40, endOffset: 150) == nil)
    }

    @Test func wordIndexFindsTheWordOnTheGuide() {
        #expect(words.wordIndex(atOffset: 0, paragraphFrames: frames, lineHeight: 40, endOffset: 150) == 0)
        #expect(words.wordIndex(atOffset: 40, paragraphFrames: frames, lineHeight: 40, endOffset: 150) == 3)
        #expect(words.wordIndex(atOffset: 150, paragraphFrames: frames, lineHeight: 40, endOffset: 150) == 6)
    }
}
