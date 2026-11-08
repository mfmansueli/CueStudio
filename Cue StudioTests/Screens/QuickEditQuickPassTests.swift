//
//  QuickEditQuickPassTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Clean up › Quick pass (E4 decision A): one tap marks what's clear (the last try of a line said more than once stays, its
/// earlier tries are marked; pauses already were); nothing is cut until Remove, which is one undo step; a try the creator
/// unmarked stays unmarked; a line with a try kept already keeps the creator's choice.
@MainActor
struct QuickEditQuickPassTests {
    private func tries(_ line: String, from start: Double) -> [CleanUpSuggestion] {
        let group = UUID()
        return (1...3).map { number in
            let begin = start + Double(number) * 3
            return CleanUpSuggestion(
                kind: .retake, span: TimeSpan(start: begin, end: begin + 2), text: line, confidence: 0.9,
                attempt: CleanUpSuggestion.Attempt(group: group, number: number, count: 3, line: line)
            )
        }
    }

    private func makeEditor(_ suggestions: [CleanUpSuggestion]) async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 3)
        var edit = TakeEdit(sourceDuration: 40, aspect: take.aspect)
        edit.suggestions = suggestions
        edit.cleanUpAnalyzed = true
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 40
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.panel = .pauses
        return viewModel
    }

    private func marked(_ viewModel: QuickEditViewModel) -> Set<UUID> {
        Set(viewModel.clips.markedCleanUp.map(\.id))
    }

    @Test func marksEarlierTriesAndRemoveIsOneStep() async throws {
        let hook = tries("Hook line", from: 0)
        let pause = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 20, end: 22), text: "", confidence: 0.95)
        let viewModel = await makeEditor(hook + [pause])
        let clips = viewModel.clips
        #expect(clips.canQuickPass)
        let before = viewModel.edit.editedDuration
        clips.quickPass()
        #expect(marked(viewModel) == [hook[0].id, hook[1].id, pause.id])
        #expect(viewModel.edit.editedDuration == before, "Nothing is cut until Remove")
        #expect(viewModel.edit.suggestions.first { $0.id == hook[2].id }?.attempt?.kept == true)
        let steps = viewModel.document.history.past.count
        clips.applyCleanUp()
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(viewModel.edit.editedDuration < before - 5)
        viewModel.undo()
        #expect(viewModel.edit.editedDuration == before)
    }

    @Test func keepsTheCreatorsChoices() async throws {
        let hook = tries("Hook line", from: 0)
        let close = tries("Closing line", from: 15)
        let viewModel = await makeEditor(hook + close)
        let clips = viewModel.clips
        let closing = try #require(clips.retakeGroups.first { $0.tries.contains { $0.id == close[0].id } })
        clips.keepTry(close[0].id, in: closing)
        clips.cleanUpMarks[hook[0].id] = false
        clips.quickPass()
        #expect(marked(viewModel) == [hook[1].id, close[1].id, close[2].id], "The first try stays kept; the unmarked try stays")
    }

    @Test func saysWhenNothingIsClear() async throws {
        let viewModel = await makeEditor([])
        #expect(!viewModel.clips.canQuickPass)
    }
}
