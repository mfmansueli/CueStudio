//
//  ScriptExpansionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A script the model wrote far too short or far too long is changed one block at a time: which blocks, and to how many words.
@Suite("Script expansion")
struct ScriptExpansionTests {
    private func block(_ words: Int, cue: String = "") -> String {
        (cue.isEmpty ? "" : cue + " ") + Array(repeating: "word", count: words).joined(separator: " ")
    }

    private func script(_ sizes: [Int]) -> String {
        sizes.map { block($0) }.joined(separator: "\n\n")
    }

    @Test func aScriptLongEnoughIsLeftAlone() {
        #expect(ScriptExpansion.steps(for: script([40, 50, 50, 30]), minimumWords: 150).isEmpty)
        #expect(ScriptExpansion.steps(for: script([30, 30, 20, 10]), minimumWords: 150).isEmpty == false, "90 of 150 words is far short")
        #expect(ScriptExpansion.steps(for: script([30, 30, 30, 20]), minimumWords: 150).isEmpty, "110 of 150 words is short, not far short")
        #expect(ScriptExpansion.steps(for: "", minimumWords: 150).isEmpty)
    }

    @Test func aScriptFarTooShortHasItsShortBlocksLengthened() {
        let steps = ScriptExpansion.steps(for: script([8, 10, 12, 6]), minimumWords: 150)
        #expect(steps.map(\.index) == [0, 1, 2, 3])
        #expect(steps.allSatisfy { !$0.isShorter && $0.target > $0.words })
        #expect(abs(steps.reduce(0) { $0 + $1.target } - 150) <= 4, "the blocks together reach the minimum")
        let byIndex = Dictionary(uniqueKeysWithValues: steps.map { ($0.index, $0.target) })
        #expect(byIndex[1] ?? 0 > byIndex[0] ?? 0 && byIndex[1] ?? 0 > byIndex[3] ?? 0, "the opening and the close are the shortest")
    }

    @Test func aBlockThatAlreadyHasItsShareIsNotLengthenedAgain() {
        let steps = ScriptExpansion.steps(for: script([5, 60, 5, 5]), minimumWords: 150)
        #expect(!steps.map(\.index).contains(1))
        #expect(steps.map(\.index).contains(0))
    }

    @Test func aScriptFarTooLongHasItsLongBlocksShortened() {
        let steps = ScriptExpansion.steps(for: script([120, 140, 100, 80]), minimumWords: 75, maximumWords: 150)
        #expect(!steps.isEmpty && steps.allSatisfy { $0.isShorter && $0.target < $0.words })
        #expect(ScriptExpansion.steps(for: script([60, 60, 40, 20]), minimumWords: 75, maximumWords: 150).isEmpty, "180 words is over 150, not far over")
    }

    @Test func stageCuesAreNotWords() {
        let withCues = "[pause] [smile] " + block(3) + " [look at camera]"
        #expect(ScriptExpansion.words(in: withCues) == 3)
    }

    @Test func theBlocksAreTheParagraphsAndTheyComeBackTogetherInOrder() {
        let text = "One two three.\n\n\n\nFour five six.\n\nSeven eight."
        let blocks = ScriptExpansion.blocks(of: text)
        #expect(blocks == ["One two three.", "Four five six.", "Seven eight."])
        #expect(ScriptExpansion.assembling(blocks, replacing: [1: "A longer middle block."]) == "One two three.\n\nA longer middle block.\n\nSeven eight.")
    }

    @Test func aStepAsksInSentencesAndKnowsWhatTheBlockIsFor() {
        let request = ScriptRequest(source: .prompt("Why I quit coffee"), platform: .tiktok, tone: nil, voice: nil, targetRange: 60...90)
        let blocks = ["I quit coffee.", "It was hard."]
        let step = ScriptExpansion.Step(index: 0, words: 3, target: 36, isShorter: false)
        let prompt = ScriptExpansionPrompt.prompt(for: step, of: blocks, request: request, purpose: "grab attention in 3 seconds")
        #expect(prompt.contains("The video: Why I quit coffee"))
        #expect(prompt.contains("This is block 1: grab attention in 3 seconds"))
        #expect(prompt.contains("exactly 3 complete sentences"), "36 words at twelve a sentence")
        #expect(prompt.hasSuffix("I quit coffee."))
        let shorter = ScriptExpansion.Step(index: 1, words: 90, target: 24, isShorter: true)
        #expect(ScriptExpansionPrompt.prompt(for: shorter, of: blocks, request: request, purpose: nil).contains("keeping only what matters"))
        #expect(ScriptExpansionPrompt.instructions(for: request, direction: .shorter).contains("shorter"))
    }
}
