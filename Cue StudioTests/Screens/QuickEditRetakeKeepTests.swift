//
//  QuickEditRetakeKeepTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Clean up › Words › a line said three times: "Keep this one" is saved with the edit (closing Clean up, or the editor, keeps it),
/// is one undo step, and an edit saved before it was saved opens with nothing kept (owner, 07/11/2026).
@MainActor
@Suite("Quick edit retakes: the try kept")
struct QuickEditRetakeKeepTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let takes: TakeLibraryService
        let library: ScriptLibraryService
        let tries: [CleanUpSuggestion]
    }

    private func tries() -> [CleanUpSuggestion] {
        let group = UUID()
        return (1...3).map { number in
            let start = Double(number) * 3
            return CleanUpSuggestion(
                kind: .retake, span: TimeSpan(start: start, end: start + 2), text: "Hook line", confidence: 0.9,
                attempt: CleanUpSuggestion.Attempt(group: group, number: number, count: 3, line: "Hook line.")
            )
        }
    }

    private func editor(for take: Take, takes: TakeLibraryService, library: ScriptLibraryService) async -> QuickEditViewModel {
        let editor = FakeTakeEditor()
        editor.duration = 30
        let viewModel = QuickEditViewModel(
            take: take, takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return viewModel
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 3)
        var edit = TakeEdit(sourceDuration: 30, aspect: take.aspect)
        let found = tries()
        edit.suggestions = found
        edit.cleanUpAnalyzed = true
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let viewModel = await editor(for: takes.takes[0], takes: takes, library: library)
        viewModel.panel = .pauses
        return Scenario(viewModel: viewModel, takes: takes, library: library, tries: found)
    }

    private func marks(_ viewModel: QuickEditViewModel, _ tries: [CleanUpSuggestion]) -> [Bool] {
        let listed = viewModel.edit.suggestions
        return tries.map { picked in viewModel.clips.isMarked(listed.first { $0.id == picked.id } ?? picked) }
    }

    @Test func nothingIsMarkedUntilATryIsKept() async throws {
        let scenario = await makeScenario()
        let group = try #require(scenario.viewModel.clips.retakeGroups.first)
        #expect(group.tries.count == 3)
        #expect(marks(scenario.viewModel, scenario.tries) == [false, false, false])
    }

    @Test func theTryKeptStaysKeptWhenCleanUpClosesAndOpensAgain() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let group = try #require(viewModel.clips.retakeGroups.first)
        viewModel.clips.keepTry(scenario.tries[1].id, in: group)
        #expect(marks(viewModel, scenario.tries) == [true, false, true])
        viewModel.panel = nil
        viewModel.panel = .pauses
        #expect(marks(viewModel, scenario.tries) == [true, false, true])
        let reopened = try #require(viewModel.clips.retakeGroups.first)
        #expect(viewModel.clips.isKeptTry(try #require(reopened.tries.first { $0.id == scenario.tries[1].id }), in: reopened))
        #expect(viewModel.clips.cleanUpApplyLabel == "Remove repeats")
    }

    @Test func keepingATryIsOneUndoStep() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let group = try #require(viewModel.clips.retakeGroups.first)
        viewModel.clips.keepTry(scenario.tries[2].id, in: group)
        #expect(viewModel.canUndo)
        viewModel.undo()
        #expect(marks(viewModel, scenario.tries) == [false, false, false], "undone")
        viewModel.redo()
        #expect(marks(viewModel, scenario.tries) == [true, true, false])
        // Tapped again: nothing of the line is marked, also saved.
        let again = try #require(viewModel.clips.retakeGroups.first)
        viewModel.clips.keepTry(scenario.tries[2].id, in: again)
        #expect(marks(viewModel, scenario.tries) == [false, false, false], "tapped again")
        #expect(viewModel.edit.suggestions.allSatisfy { $0.attempt?.kept == nil })
    }

    @Test func theTryKeptIsThereWhenTheProjectOpensAgain() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let group = try #require(viewModel.clips.retakeGroups.first)
        viewModel.clips.keepTry(scenario.tries[0].id, in: group)
        #expect(viewModel.done() == true)
        // What the take keeps, written and read back as the app's files do, in a new editor.
        var take = try #require(scenario.takes.takes.first)
        let saved = try #require(take.edit)
        take.edit = try JSONDecoder().decode(TakeEdit.self, from: JSONEncoder().encode(saved))
        let again = await editor(for: take, takes: scenario.takes, library: scenario.library)
        again.panel = .pauses
        #expect(marks(again, scenario.tries) == [false, true, true])
    }

    @Test func aTrySavedBeforeKeptWasSavedOpensWithNothingKept() throws {
        let attempt = CleanUpSuggestion.Attempt(group: UUID(), number: 1, count: 2, line: "Hook line.")
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(attempt)) as? [String: Any])
        json["kept"] = nil
        let old = try JSONDecoder().decode(CleanUpSuggestion.Attempt.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.kept == nil)
        #expect(old.line == "Hook line.")
    }
}
