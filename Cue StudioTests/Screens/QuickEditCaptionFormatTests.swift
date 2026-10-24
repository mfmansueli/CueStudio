//
//  QuickEditCaptionFormatTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Caption style › Format in the editor: new captions start as short phrases, an edit from before formats keeps its lines until
/// one is picked, a change is one undo step that keeps the words, a translation keeps its own lines and points at the new
/// blocks, the picked line stays picked, and lines cut by hand stay.
@MainActor
@Suite("Quick edit caption formats")
struct QuickEditCaptionFormatTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
    }

    private static let said = "So today I want to show you the three habits that changed my mornings and how you can start them tomorrow"

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let words = CaptionText.words(in: Self.said).enumerated().map { index, word in
            CaptionWord(text: word, start: 1 + Double(index) * 0.3, end: 1 + Double(index) * 0.3 + 0.25)
        }
        editor.captions = [CaptionCue(words: words)]
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, editor: editor)
    }

    private func makeCaptions(_ viewModel: QuickEditViewModel) async {
        viewModel.captions.makeCaptions()
        await viewModel.jobs.finished(.captions)
    }

    @Test func newCaptionsStartAsShortPhrases() async {
        let viewModel = await makeScenario().viewModel
        await makeCaptions(viewModel)
        #expect(viewModel.captions.captionFormat == .phrase)
        #expect(viewModel.edit.captions.count > 1)
        #expect(CaptionText.joined(viewModel.edit.captions.map(\.text)) == Self.said)
    }

    /// An edit saved before formats has none: its lines are drawn as they were made, and making them again keeps that way.
    @Test func anEditFromBeforeFormatsKeepsItsLines() async throws {
        let viewModel = await makeScenario().viewModel
        let old = CaptionCue(text: "A line from an old edit", start: 1, end: 3)
        viewModel.changeEdit { edit in
            edit.captions = [old]
            edit.captionCollection?.format = nil
        }
        let saved = try JSONEncoder().encode(viewModel.edit.captionCollection)
        let read = try JSONDecoder().decode(CaptionSettings.self, from: saved)
        #expect(read.format == nil)
        #expect(viewModel.edit.captions == [old])
        await makeCaptions(viewModel)
        #expect(viewModel.captions.captionFormat == nil)
    }

    @Test func aFormatIsOneUndoStepThatKeepsTheWords() async {
        let viewModel = await makeScenario().viewModel
        await makeCaptions(viewModel)
        let phrases = viewModel.edit.captions
        viewModel.captions.setCaptionFormat(.oneWord)
        #expect(viewModel.edit.captions.count == CaptionText.words(in: Self.said).count)
        #expect(viewModel.captions.captionFormat == .oneWord)
        viewModel.captions.setCaptionFormat(.twoLines)
        #expect(viewModel.edit.captions.count < phrases.count)
        #expect(CaptionText.joined(viewModel.edit.captions.map(\.text)) == Self.said)
        viewModel.undo()
        #expect(viewModel.captions.captionFormat == .oneWord)
        viewModel.undo()
        #expect(viewModel.edit.captions == phrases)
        #expect(viewModel.captions.captionFormat == .phrase)
    }

    /// A translation keeps its own lines and times (never split word by word) and points at the blocks it plays over.
    @Test func aTranslationKeepsItsLinesAndPointsAtTheBlocks() async throws {
        let viewModel = await makeScenario().viewModel
        await makeCaptions(viewModel)
        let first = try #require(viewModel.edit.captions.first)
        let translated = TranslatedCaptionLine(
            cueIDs: [first.id], sourceText: first.text, text: "Então hoje quero mostrar", start: first.start, end: first.end,
            sourceID: nil, isRevised: false
        )
        viewModel.changeEdit { $0.captionTranslations = [CaptionTranslation(language: .portugueseBrazil, lines: [translated])] }
        viewModel.captions.setCaptionFormat(.oneWord)
        let line = try #require(viewModel.edit.captionTranslations.first?.lines.first)
        #expect(line.text == translated.text)
        #expect(line.start == translated.start && line.end == translated.end)
        let pointed = Set(line.cueIDs)
        #expect(pointed.count > 1)
        #expect(pointed.isSubset(of: Set(viewModel.edit.captions.map(\.id))))
    }

    @Test func thePickedLineStaysPicked() async throws {
        let viewModel = await makeScenario().viewModel
        await makeCaptions(viewModel)
        let second = try #require(viewModel.edit.captions.dropFirst().first)
        viewModel.selection = .caption(second.id)
        viewModel.captions.setCaptionFormat(.oneWord)
        let picked = try #require(viewModel.edit.captions.first { $0.id == viewModel.selectedCaptionID })
        #expect(picked.span.contains(second.start))
    }

    /// A line split or joined by hand keeps its edges whatever the format.
    @Test func linesCutByHandKeepTheirEdges() async throws {
        let viewModel = await makeScenario().viewModel
        await makeCaptions(viewModel)
        viewModel.captions.setCaptionFormat(.twoLines)
        let block = try #require(viewModel.edit.captions.first)
        viewModel.captions.splitCaption(block.id, beforeWord: 2)
        let split = Array(viewModel.edit.captions.prefix(2))
        #expect(split.allSatisfy(\.keepsBlock))
        viewModel.captions.setCaptionFormat(.oneWord)
        #expect(Array(viewModel.edit.captions.prefix(2)) == split)
    }

    /// `keepsBlock` is written only when set: lines that never had it read and write as before.
    @Test func aKeptBlockIsSavedAndOldLinesReadWithoutIt() throws {
        var line = CaptionCue(text: "Kept", start: 0, end: 1)
        let plain = try JSONEncoder().encode(line)
        #expect(!String(decoding: plain, as: UTF8.self).contains("keepsBlock"))
        line.keepsBlock = true
        let kept = try JSONDecoder().decode(CaptionCue.self, from: JSONEncoder().encode(line))
        #expect(kept.keepsBlock)
        #expect(try !JSONDecoder().decode(CaptionCue.self, from: plain).keepsBlock)
    }

    /// Caption › Line break at the cursor: the same words and times on two lines, kept as the creator broke it, one undo step.
    @Test func aLineBreakAtTheCursorKeepsTheWordsAndTheirTimes() async throws {
        let viewModel = await makeScenario().viewModel
        await makeCaptions(viewModel)
        let first = try #require(viewModel.edit.captions.first)
        let cursor = try #require(first.text.range(of: " ")).upperBound
        viewModel.captions.breakCaptionLine(first.id, atCharacter: first.text.distance(from: first.text.startIndex, to: cursor))
        let broken = try #require(viewModel.edit.captions.first { $0.id == first.id })
        #expect(broken.lineBreaks == [0])
        #expect(broken.keepsBlock)
        #expect(broken.words.map(\.start) == first.words.map(\.start))
        viewModel.undo()
        #expect(viewModel.edit.captions.first == first)
    }

    /// Word timing: a handle moves where one word ends and the next starts, never closer than a tenth to their other ends;
    /// a drag is one undo step, and words with estimated times become times the creator set only where the handle moved.
    @Test func aWordBoundaryMovesBothWordsInOneUndoStep() async throws {
        let viewModel = await makeScenario().viewModel
        await makeCaptions(viewModel)
        let first = try #require(viewModel.edit.captions.first)
        let boundary = (first.words[0].end + first.words[1].start) / 2
        viewModel.captions.setWordBoundary(first.id, after: 0, at: boundary + 0.05)
        viewModel.captions.setWordBoundary(first.id, after: 0, at: boundary + 0.08)
        viewModel.endChange()
        let timed = try #require(viewModel.edit.captions.first { $0.id == first.id })
        #expect(abs(timed.words[0].end - (boundary + 0.08)) < 0.000_1)
        #expect(timed.words[1].start == timed.words[0].end)
        #expect(timed.isRevised)
        viewModel.captions.setWordBoundary(first.id, after: 0, at: -5)
        viewModel.endChange()
        let clamped = try #require(viewModel.edit.captions.first { $0.id == first.id })
        #expect(abs(clamped.words[0].end - (clamped.words[0].start + 0.1)) < 0.000_1)
        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.captions.first { $0.id == first.id } == first)

        let written = CaptionCue(text: "Written by hand here", start: 20, end: 22, origin: .manual)
        viewModel.changeEdit { $0.captions.append(written) }
        viewModel.captions.setWordBoundary(written.id, after: 1, at: 21)
        let set = try #require(viewModel.edit.captions.first { $0.id == written.id })
        #expect(set.words.map(\.isEstimated) == [true, false, false, true])
        #expect(!set.hasWordTiming)
    }
}
