//
//  QuickEditCaptionPicksTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Captions › Select: several lines picked, then emphasized, sized, moved or deleted together, each one undo step; moving
/// stops at the clip's edge and at the lines that weren't picked; leaving the list ends the picking.
@MainActor
@Suite("Quick edit caption picks")
struct QuickEditCaptionPicksTests {
    private func makeViewModel(lines: [(TimeInterval, TimeInterval, String)]) async -> (QuickEditViewModel, ToastService) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.changeEdit {
            $0.captions = lines.map { CaptionCue(text: $0.2, start: $0.0, end: $0.1) }
            $0.showsCaptions = true
        }
        viewModel.panel = .captions
        return (viewModel, toast)
    }

    private func ids(_ viewModel: QuickEditViewModel) -> [UUID] {
        viewModel.edit.captions.sorted { $0.start < $1.start }.map(\.id)
    }

    @Test func pickingStartsEmptyTogglesAndSelectsAll() async {
        let (viewModel, _) = await makeViewModel(lines: [(0, 1, "a"), (2, 3, "b"), (4, 5, "c")])
        let lines = ids(viewModel)
        viewModel.selection = .caption(lines[0])
        viewModel.captions.startPickingCaptions()
        #expect(viewModel.captions.captionPicks == [])
        #expect(viewModel.selection == nil)
        viewModel.captions.toggleCaptionPick(lines[1])
        viewModel.captions.toggleCaptionPick(lines[2])
        viewModel.captions.toggleCaptionPick(lines[1])
        #expect(viewModel.captions.captionPicks == [lines[2]])
        viewModel.captions.togglePickAllCaptions()
        #expect(viewModel.captions.picksEveryCaption)
        viewModel.captions.togglePickAllCaptions()
        #expect(viewModel.captions.captionPicks == [])
        viewModel.captions.startPickingCaptions(with: lines[0])
        #expect(viewModel.captions.captionPicks == [lines[0]])
        // Leaving the list of lines ends the picking.
        viewModel.panel = .captionStyle
        #expect(viewModel.captions.captionPicks == nil)
    }

    @Test func emphasisAndSizeGoOnThePickedLinesOnlyAsOneStep() async {
        let (viewModel, _) = await makeViewModel(lines: [(0, 1, "a"), (2, 3, "b"), (4, 5, "c")])
        let lines = ids(viewModel)
        viewModel.captions.startPickingCaptions()
        viewModel.captions.toggleCaptionPick(lines[0])
        viewModel.captions.toggleCaptionPick(lines[2])
        let steps = viewModel.document.history.past.count
        viewModel.captions.setPickedCaptionsEmphasized(true)
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(viewModel.captions.pickedCaptionsAreEmphasized)
        let styles = Dictionary(uniqueKeysWithValues: viewModel.edit.captions.map { ($0.id, $0.lineStyle) })
        #expect(styles[lines[0]]??.isEmphasized == true && styles[lines[2]]??.isEmphasized == true)
        #expect(styles[lines[1]] ?? nil == nil)
        viewModel.captions.setPickedCaptionSize(.bigger)
        #expect(viewModel.captions.pickedCaptionSize == .bigger)
        // Back to plain: no style left on the line.
        viewModel.captions.setPickedCaptionsEmphasized(false)
        viewModel.captions.setPickedCaptionSize(.regular)
        #expect(viewModel.edit.captions.allSatisfy { $0.lineStyle == nil })
        viewModel.undo()
        #expect(viewModel.captions.pickedCaptionSize == .bigger)
    }

    @Test func oldCaptionsWithoutACollectionCantBeStyledApart() async {
        let (viewModel, _) = await makeViewModel(lines: [(0, 1, "a")])
        viewModel.changeEdit { $0.captionCollection = nil }
        viewModel.captions.startPickingCaptions(with: viewModel.edit.captions[0].id)
        #expect(!viewModel.captions.canStyleCaptionLines)
        viewModel.captions.setPickedCaptionsEmphasized(true)
        #expect(viewModel.edit.captions[0].lineStyle == nil)
    }

    @Test func pickedLinesMoveTogetherAndStopAtTheOthers() async {
        let (viewModel, toast) = await makeViewModel(lines: [(0, 1, "a"), (1.3, 2, "b"), (2.2, 3, "c"), (3.5, 4, "d")])
        let lines = ids(viewModel)
        viewModel.captions.startPickingCaptions()
        viewModel.captions.toggleCaptionPick(lines[1])
        viewModel.captions.toggleCaptionPick(lines[2])
        let steps = viewModel.document.history.past.count
        #expect(viewModel.captions.movePickedCaptions(by: 0.1))
        #expect(viewModel.captions.movePickedCaptions(by: 0.1))
        let moved = Dictionary(uniqueKeysWithValues: viewModel.edit.captions.map { ($0.id, $0) })
        #expect(abs((moved[lines[1]]?.start ?? 0) - 1.5) < 0.000_1)
        #expect(abs((moved[lines[2]]?.end ?? 0) - 3.2) < 0.000_1)
        #expect(moved[lines[0]]?.start == 0 && moved[lines[3]]?.start == 3.5)
        // Quick taps are one undo step.
        #expect(viewModel.document.history.past.count == steps + 1)
        // "c" ends at 3.2; "d" starts at 3.5: the group goes 0.3 further and no more.
        #expect(viewModel.captions.movePickedCaptions(by: 1))
        #expect(abs((viewModel.edit.captions.first { $0.id == lines[2] }?.end ?? 0) - 3.5) < 0.000_1)
        #expect(!viewModel.captions.movePickedCaptions(by: 0.1))
        #expect(toast.message == "The lines can’t move further")
        // Earlier, "b" stops at "a"'s end.
        #expect(viewModel.captions.movePickedCaptions(by: -5))
        #expect(abs((viewModel.edit.captions.first { $0.id == lines[1] }?.start ?? 0) - 1) < 0.000_1)
    }

    @Test func linesKeepTheirWordsWhenMoved() async {
        let (viewModel, _) = await makeViewModel(lines: [])
        let heard = CaptionCue(words: [CaptionWord(text: "hi", start: 1, end: 1.2), CaptionWord(text: "there", start: 1.3, end: 1.6)])
        viewModel.changeEdit { $0.captions = [heard] }
        viewModel.captions.startPickingCaptions(with: heard.id)
        viewModel.captions.movePickedCaptions(by: -0.5)
        let moved = viewModel.edit.captions[0]
        #expect(abs(moved.start - 0.5) < 0.000_1)
        #expect(abs(moved.words[1].start - 0.8) < 0.000_1)
        #expect(moved.text == "hi there")
    }

    @Test func pickedLinesAreDeletedTogetherWithUndo() async {
        let (viewModel, toast) = await makeViewModel(lines: [(0, 1, "a"), (2, 3, "b"), (4, 5, "c")])
        let lines = ids(viewModel)
        viewModel.captions.startPickingCaptions()
        viewModel.captions.toggleCaptionPick(lines[0])
        viewModel.captions.toggleCaptionPick(lines[1])
        viewModel.captions.deletePickedCaptions()
        #expect(viewModel.edit.captions.map(\.id) == [lines[2]])
        #expect(viewModel.captions.captionPicks == nil)
        #expect(toast.message == "2 lines deleted")
        viewModel.undo()
        #expect(viewModel.edit.captions.count == 3)
    }
}
