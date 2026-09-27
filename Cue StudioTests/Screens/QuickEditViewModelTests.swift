//
//  QuickEditViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("QuickEditViewModel")
struct QuickEditViewModelTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let takes: TakeLibraryService
        let editor: FakeTakeEditor
        let toast: ToastService
    }

    private func makeScenario(script: Script? = TestData.script(text: "Okay, real talk.")) -> Scenario {
        var take = TestData.take(scriptID: script?.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: script.map { [$0] } ?? []))
        library.load()
        let editor = FakeTakeEditor()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(take: take, takes: takes, library: library, editing: editor, toast: toast)
        return Scenario(viewModel: viewModel, takes: takes, editor: editor, toast: toast)
    }

    @Test func startsFromTheWholeTake() {
        let scenario = makeScenario()
        #expect(scenario.viewModel.durationChange == "1:04 → 1:04")
        #expect(scenario.viewModel.edit.aspect == .portrait)
    }

    @Test func splittingAtThePlayheadAndDeletingASection() {
        let scenario = makeScenario()
        scenario.viewModel.movePlayhead(to: 20)
        scenario.viewModel.split()
        #expect(scenario.toast.message == "Split at 0:20")
        scenario.viewModel.movePlayhead(to: 10)
        #expect(scenario.viewModel.canDeleteSelection)
        scenario.viewModel.deleteSelection()
        #expect(scenario.viewModel.edit.editedDuration == 44)
        #expect(scenario.viewModel.durationChange == "1:04 → 0:44")
    }

    @Test func splitOutsideTheClipExplains() {
        let scenario = makeScenario()
        scenario.viewModel.movePlayhead(to: 0)
        scenario.viewModel.split()
        #expect(scenario.toast.message == "Move the playhead inside the clip")
    }

    @Test func removeSilencesFindsThenToggles() async {
        let scenario = makeScenario()
        await scenario.viewModel.toggleRemoveSilences()
        #expect(scenario.viewModel.edit.removesSilences)
        #expect(scenario.viewModel.silenceLabel == "Silences removed · −3s")
        await scenario.viewModel.toggleRemoveSilences()
        #expect(scenario.viewModel.silenceLabel == "Remove silences · 2")
    }

    @Test func captionsComeFromTheScript() async {
        let scenario = makeScenario()
        await scenario.viewModel.setShowsCaptions(true)
        #expect(scenario.viewModel.edit.showsCaptions)
        #expect(scenario.editor.captionScript == "Okay, real talk.")
        #expect(scenario.viewModel.edit.captions.count == 1)
    }

    @Test func pickingAStyleTurnsCaptionsOn() async {
        let scenario = makeScenario()
        await scenario.viewModel.setCaptionStyle(.highlight)
        #expect(scenario.viewModel.edit.showsCaptions)
        #expect(scenario.viewModel.edit.captionStyle == .highlight)
    }

    @Test func autoAdjustsTheLook() {
        let scenario = makeScenario()
        scenario.viewModel.autoAdjust()
        #expect(scenario.viewModel.edit.exposure == 14)
        #expect(scenario.toast.message == "Auto-enhanced")
    }

    @Test func doneSavesTheEditTheNewLengthAndMarksTheTakeEdited() {
        let scenario = makeScenario()
        scenario.viewModel.setTrimStart(4)
        scenario.viewModel.done()
        let saved = scenario.takes.takes[0]
        #expect(saved.isEdited)
        #expect(saved.duration == 60)
        #expect(saved.edit?.trimStart == 4)
        #expect(scenario.toast.message == "Edits saved to Take 3")
    }

    @Test func editingAgainStartsFromTheSavedEdit() {
        let scenario = makeScenario()
        scenario.viewModel.setTrimStart(4)
        scenario.viewModel.done()
        let again = QuickEditViewModel(
            take: scenario.takes.takes[0], takes: scenario.takes,
            library: ScriptLibraryService(repository: FakeScriptRepository()), editing: FakeTakeEditor(), toast: ToastService()
        )
        #expect(again.edit.sourceDuration == 64)
        #expect(again.edit.trimStart == 4)
    }
}
