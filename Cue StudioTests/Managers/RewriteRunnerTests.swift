//
//  RewriteRunnerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The runner edits a script a part at a time and holds each part to its tool's promise, whatever the model does.
@MainActor
@Suite("Rewrite runner")
struct RewriteRunnerTests {
    /// What the pretend model was asked, and what it will answer.
    private final class Model: @unchecked Sendable {
        private(set) var asked: [(text: String, part: ScriptPromptBuilder.RewritePart)] = []
        private let answer: @Sendable (String, Int) throws -> String

        init(_ answer: @escaping @Sendable (_ text: String, _ nth: Int) throws -> String) { self.answer = answer }

        var ask: RewriteRunner.Ask {
            { [self] text, part in
                asked.append((text, part))
                return try answer(text, asked.filter { $0.text == text }.count)
            }
        }
    }

    private static let context = RewriteContext(structure: .generic, platform: .tiktok, idealRange: 60...90)

    private nonisolated static func paragraph(_ index: Int, words: Int = 60) -> String {
        (0..<words).map { "word\(index)x\($0)" }.joined(separator: " ") + "."
    }

    private nonisolated static func script(paragraphs: Int, words: Int = 60) -> String {
        (0..<paragraphs).map { paragraph($0, words: words) }.joined(separator: "\n\n")
    }

    private nonisolated static func firstWords(_ text: String, _ count: Int) -> String {
        text.split(separator: " ").prefix(count).joined(separator: " ")
    }

    @Test func aShortScriptIsEditedInOneRequest() async throws {
        let model = Model { text, _ in text.replacingOccurrences(of: "dont", with: "don’t") }
        let result = try await RewriteRunner.run(
            "i dont know why my mornings was a mess, but it took me three weeks to fix it.", tool: .fixGrammar, context: Self.context, ask: model.ask
        )
        #expect(result.text.contains("don’t"))
        #expect(model.asked.count == 1)
        #expect(result.parts == 1 && result.leftAsWritten == 0)
    }

    @Test func aLongScriptComesBackWholeAPartAtATime() async throws {
        let text = Self.script(paragraphs: 12, words: 70)
        let model = Model { text, _ in text + " ok" }
        let result = try await RewriteRunner.run(text, tool: .fixGrammar, context: Self.context, ask: model.ask)
        #expect(model.asked.count >= 4)
        #expect(model.asked.allSatisfy { $0.part.count == model.asked.count })
        #expect(ReadTime.wordCount(in: result.text) >= ReadTime.wordCount(in: text))
        #expect(result.leftAsWritten == 0)
    }

    @Test func aModelThatCutsTheScriptShortIsAskedAgainAndThenLeftOut() async throws {
        let text = Self.script(paragraphs: 3, words: 60)
        let model = Model { text, _ in String(text.prefix(text.count / 3)) }
        let result = try await RewriteRunner.run(text, tool: .fixGrammar, context: Self.context, ask: model.ask)
        #expect(result.text == text, "what the model cut away is never taken in")
        #expect(result.isUntouched)
        #expect(model.asked.count == result.parts * 2)
        #expect(model.asked.last?.part.correction?.contains("Write it again") == true)
    }

    @Test func aSecondAnswerThatKeepsThePromiseIsTaken() async throws {
        let text = Self.script(paragraphs: 1, words: 100)
        let model = Model { text, nth in nth == 1 ? text : Self.firstWords(text, 60) }
        let result = try await RewriteRunner.run(text, tool: .shorterAndDirect, context: Self.context, ask: model.ask)
        #expect(ReadTime.wordCount(in: result.text) == 60)
        #expect(model.asked.count == 2)
        #expect(result.leftAsWritten == 0)
    }

    @Test func aVoiceThatSaysItInFewerWordsIsTakenAndOneThatEmptiesTheScriptIsNot() async throws {
        let text = Self.script(paragraphs: 1, words: 100)
        let concise = Model { text, _ in Self.firstWords(text, 45) }
        let taken = try await RewriteRunner.run(text, tool: .inMyVoice, context: Self.context, ask: concise.ask)
        #expect(ReadTime.wordCount(in: taken.text) == 45)
        let gutted = Model { text, _ in Self.firstWords(text, 20) }
        let refused = try await RewriteRunner.run(text, tool: .inMyVoice, context: Self.context, ask: gutted.ask)
        #expect(refused.text == text && refused.isUntouched)
    }

    @Test func shorterThatOnlyEverGrowsLeavesTheScriptAsItWas() async throws {
        let text = Self.script(paragraphs: 1, words: 100)
        let model = Model { text, _ in text + " " + Self.paragraph(9, words: 20) }
        let result = try await RewriteRunner.run(text, tool: .shorterAndDirect, context: Self.context, ask: model.ask)
        #expect(result.text == text)
        #expect(result.isUntouched)
    }

    @Test func aShorterThatCutsLessThanAskedStillCounts() async throws {
        let text = Self.script(paragraphs: 1, words: 100)
        let model = Model { text, _ in Self.firstWords(text, 95) }
        let result = try await RewriteRunner.run(text, tool: .shorterAndDirect, context: Self.context, ask: model.ask)
        #expect(ReadTime.wordCount(in: result.text) == 95)
        #expect(result.leftAsWritten == 0)
    }

    @Test func aSceneTheModelMadeUpDoesNotReachTheScript() async throws {
        let text = "i dont know why but my mornings was a mess and it took me three weeks to get it right."
        let model = Model { _, _ in "[Scene: Interior, morning light.]\n\nI don’t know why, but my mornings were a mess and it took me three weeks to get it right." }
        let result = try await RewriteRunner.run(text, tool: .fixGrammar, context: Self.context, ask: model.ask)
        #expect(!result.text.contains("[Scene"))
        #expect(result.text.hasPrefix("I don’t know why"))
    }

    @Test func aStrongerCTAChangesTheClosingAndNothingElse() async throws {
        let text = Self.script(paragraphs: 4, words: 40)
        let model = Model { _, _ in "Follow now, and send this to a friend who needs it today, because it takes only a minute to try and see." }
        let result = try await RewriteRunner.run(text, tool: .strongerCTA, context: Self.context, ask: model.ask)
        #expect(model.asked.count == 1)
        #expect(model.asked[0].text == Self.paragraph(3, words: 40))
        #expect(model.asked[0].part.leadIn == Self.paragraph(2, words: 40))
        #expect(result.text.hasPrefix(Self.script(paragraphs: 3, words: 40)))
        #expect(result.text.hasSuffix("it takes only a minute to try and see."))
    }

    @Test func aScriptThatAlreadyFitsIsNotMoved() async throws {
        let words = ReadTime.words(for: 75)
        let text = Self.script(paragraphs: 1, words: words)
        let model = Model { text, _ in text + " more" }
        let result = try await RewriteRunner.run(text, tool: .fitToTime, context: Self.context, ask: model.ask)
        #expect(model.asked.isEmpty)
        #expect(result.text == text && result.isUntouched)
    }

    @Test func aLongScriptIsCutToTheLengthPartByPart() async throws {
        let text = Self.script(paragraphs: 8, words: 70)
        let model = Model { text, _ in
            // The model cuts each part to about half.
            let words = text.split(separator: " ")
            return words.prefix(words.count * 4 / 10).joined(separator: " ")
        }
        let result = try await RewriteRunner.run(text, tool: .fitToTime, context: Self.context, ask: model.ask)
        let low = ReadTime.words(for: 60), high = ReadTime.words(for: 90)
        let count = ReadTime.wordCount(in: result.text)
        #expect(count < ReadTime.wordCount(in: text))
        #expect(count >= Int(Double(low) * 0.7) && count <= Int(Double(high) * 1.3), "\(count) words for \(low)–\(high)")
    }

    @Test func aPartTheModelWontTouchIsLeftAndTheOthersAreDone() async throws {
        let text = Self.script(paragraphs: 8, words: 70)
        let first = String(text.prefix(40))
        let model = Model { part, _ in
            if part.hasPrefix(first) { throw ScriptAIError.declined }
            return part + " ok"
        }
        let result = try await RewriteRunner.run(text, tool: .fixGrammar, context: Self.context, ask: model.ask)
        #expect(result.leftAsWritten == 1)
        #expect(result.text.hasPrefix(first))
        #expect(result.text.contains("ok"))
    }

    @Test func whenTheModelWontTouchAnythingTheCreatorIsTold() async {
        let model = Model { _, _ in throw ScriptAIError.declined }
        await #expect(throws: ScriptAIError.self) {
            _ = try await RewriteRunner.run(Self.script(paragraphs: 6, words: 70), tool: .fixGrammar, context: Self.context, ask: model.ask)
        }
        await #expect(throws: ScriptAIError.self) {
            _ = try await RewriteRunner.run("A short script that is all one part.", tool: .fixGrammar, context: Self.context, ask: model.ask)
        }
    }

    @Test func errorsThatAreNotAboutOnePartStopEverything() async {
        let model = Model { _, _ in throw ScriptAIError.rateLimited }
        await #expect(throws: ScriptAIError.self) {
            _ = try await RewriteRunner.run(Self.script(paragraphs: 6, words: 70), tool: .moreEnergy, context: Self.context, ask: model.ask)
        }
        #expect(model.asked.count == 1)
    }

    @Test func eachPartKnowsWhereItIs() async throws {
        let model = Model { text, _ in text }
        _ = try await RewriteRunner.run(Self.script(paragraphs: 10, words: 70), tool: .moreHuman, context: Self.context, ask: model.ask)
        let indexes = model.asked.map(\.part.index)
        #expect(Set(indexes) == Set(1...(indexes.max() ?? 1)))
        #expect(indexes == indexes.sorted())
        #expect(model.asked.allSatisfy { $0.part.count == indexes.max() })
    }
}
