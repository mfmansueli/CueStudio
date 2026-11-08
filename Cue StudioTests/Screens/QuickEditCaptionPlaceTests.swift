//
//  QuickEditCaptionPlaceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Captions › Select › Place and the preview's drag of a line in its own place (E4 D): one undo step each; a stretch moves alone,
/// any other caption moves every caption but those, and a toast offers to bring them along.
@MainActor
struct QuickEditCaptionPlaceTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let toast: ToastService
    }

    private let first = CaptionCue(text: "first line here", start: 0, end: 2, origin: .manual)
    private let second = CaptionCue(text: "second line here", start: 2.5, end: 4.5, origin: .manual)
    private let third = CaptionCue(text: "third line here", start: 5, end: 7, origin: .manual)

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.changeEdit {
            $0.captions = [first, second, third]
            $0.showsCaptions = true
            if $0.captionCollection == nil { $0.captionCollection = CaptionSettings() }
        }
        return Scenario(viewModel: viewModel, toast: toast)
    }

    private func place(_ id: UUID, _ viewModel: QuickEditViewModel) -> Double? {
        viewModel.edit.captions.first { $0.id == id }?.lineStyle?.y
    }

    @Test func picksGoToTheirOwnPlaceAndBackOneStepEach() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.captions.startPickingCaptions(with: first.id)
        viewModel.captions.toggleCaptionPick(second.id)
        #expect(viewModel.captions.pickedCaptionPlace == .withAll)
        let steps = viewModel.document.history.past.count
        viewModel.captions.setPickedCaptionsPlace(.own(.top))
        #expect(place(first.id, viewModel) == CaptionPosition.top.verticalFraction)
        #expect(place(second.id, viewModel) == CaptionPosition.top.verticalFraction)
        #expect(place(third.id, viewModel) == nil)
        #expect(viewModel.captions.pickedCaptionPlace == .own(.top))
        #expect(viewModel.document.history.past.count == steps + 1)
        // The same place again: nothing changes, no step.
        viewModel.captions.setPickedCaptionsPlace(.own(.top))
        #expect(viewModel.document.history.past.count == steps + 1)
        viewModel.captions.setPickedCaptionsPlace(.withAll)
        #expect(place(first.id, viewModel) == nil)
        #expect(viewModel.edit.captions.allSatisfy { $0.lineStyle == nil }, "Back with the rest: no style left")
        viewModel.undo()
        #expect(place(first.id, viewModel) == CaptionPosition.top.verticalFraction)
    }

    @Test func aStretchDragsAloneAndOthersDragEveryCaptionButIt() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.captions.startPickingCaptions(with: first.id)
        viewModel.captions.toggleCaptionPick(second.id)
        viewModel.captions.setPickedCaptionsPlace(.own(.top))
        viewModel.captions.stopPickingCaptions()

        #expect(viewModel.captions.captionDragLines(first.id) == [first.id, second.id])
        #expect(viewModel.captions.captionDragScope(first.id) == "This stretch")
        #expect(viewModel.captions.captionDragLines(third.id) == nil)
        #expect(viewModel.captions.captionDragScope(third.id) == "All captions")

        viewModel.captions.moveCaption(first.id, toY: 0.505)
        #expect(place(first.id, viewModel) == 0.5, "Sticks to the middle")
        #expect(place(second.id, viewModel) == 0.5)
        #expect(viewModel.captions.captionY(of: third.id) != 0.5)

        viewModel.captions.moveCaption(third.id, toY: 0.3)
        #expect(viewModel.edit.captionCollection?.center?.y == 0.3)
        #expect(place(first.id, viewModel) == 0.5, "Its own place stays")
        #expect(scenario.toast.message == "2 lines keep their own place")
        scenario.toast.action?.perform()
        #expect(viewModel.edit.captions.allSatisfy { $0.lineStyle?.y == nil })
    }
}
