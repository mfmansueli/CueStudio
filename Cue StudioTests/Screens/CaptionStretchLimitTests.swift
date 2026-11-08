//
//  CaptionStretchLimitTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Stretching a caption line (owner, 08/11/2026): each end goes to the first limit it meets, the next (or previous) line or its
/// clip's cut, and says which by the handle, with one haptic per gesture; the neighbor and the words keep their time; one undo step
/// when the line changed, none when it was already at its limit.
@MainActor
struct CaptionStretchLimitTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
    }

    /// One recording of 30 s, cut at 10 s (two clips: 0–10, 10–30).
    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 30
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 30
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        player.seek(to: 10)
        viewModel.clips.selectClipAtPlayhead()
        viewModel.clips.splitClip()
        viewModel.selection = nil
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    private func line(_ text: String, _ start: TimeInterval, _ end: TimeInterval) -> CaptionCue {
        var cue = CaptionCue(text: text, start: start, end: end, origin: .manual)
        cue.words = [CaptionWord(text: text, start: start + 0.1, end: end - 0.1, isEstimated: false)]
        return cue
    }

    private func lay(_ lines: [CaptionCue], on viewModel: QuickEditViewModel) {
        viewModel.changeEdit {
            $0.captions = lines
            $0.showsCaptions = true
        }
    }

    private func cue(_ id: UUID, in viewModel: QuickEditViewModel) -> CaptionCue? {
        viewModel.edit.captions.first { $0.id == id }
    }

    // MARK: - The room

    @Test func eachEndMeetsTheFirstLimitAndNamesIt() {
        var timeline = EditTimeline(sourceDuration: 30)
        _ = timeline.split(atEdited: 10)
        let beforeTheCut = CaptionStretchRoom(span: TimeSpan(start: 6, end: 8), previousEnd: 2, nextStart: 12, timeline: timeline)
        #expect(beforeTheCut.start == 2 && beforeTheCut.startLimit == .line)
        #expect(beforeTheCut.end == 10 && beforeTheCut.endLimit == .cut)
        #expect(beforeTheCut.hint(for: .end) == "Stops at the cut")
        #expect(beforeTheCut.hint(for: .start) == "Stops at the line before")

        let nextFirst = CaptionStretchRoom(span: TimeSpan(start: 6, end: 8), previousEnd: nil, nextStart: 9, timeline: timeline)
        #expect(nextFirst.end == 9 && nextFirst.endLimit == .line)
        #expect(nextFirst.hint(for: .end) == "Stops at the next line")
        #expect(nextFirst.start == 0 && nextFirst.startLimit == .edge)
        #expect(nextFirst.hint(for: .start) == nil, "The video's own start needs no words")

        let afterTheCut = CaptionStretchRoom(span: TimeSpan(start: 12, end: 14), previousEnd: 8, nextStart: nil, timeline: timeline)
        #expect(afterTheCut.start == 10 && afterTheCut.startLimit == .cut)
        #expect(afterTheCut.end == 30 && afterTheCut.endLimit == .edge)
    }

    // MARK: - The handle on the timeline

    @Test func theEndStopsAtTheCutSaysSoAndKeepsTheNeighborAndTheWords() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let first = line("five dishes", 7, 9), second = line("from São Paulo", 11, 13)
        lay([first, second], on: viewModel)
        viewModel.selection = .caption(first.id)

        viewModel.beginTimelineHandle(.item(.caption, first.id, .end), snapTimes: [])
        let moving = viewModel.moveTimelineHandle(by: 0.5)
        #expect(!moving.label.hasPrefix("Stops"), "Inside its room the handle shows the time")
        #expect(viewModel.stretchLimitNoticed == false)
        let held = viewModel.moveTimelineHandle(by: 4)
        #expect(held.label == "Stops at the cut")
        #expect(viewModel.stretchLimitNoticed, "The haptic tapped once")
        _ = viewModel.moveTimelineHandle(by: 6)
        #expect(viewModel.stretchLimitNoticed)
        viewModel.endTimelineHandle()
        #expect(viewModel.stretchLimitNoticed == false, "The next gesture taps again")

        let stretched = try #require(cue(first.id, in: viewModel))
        #expect(abs(stretched.end - 10) < 0.001)
        #expect(abs((viewModel.captions.editedSpan(ofCaption: first.id)?.end ?? 0) - 10) < 0.001, "It shows that long, past its words")
        #expect(stretched.words.map(\.start) == first.words.map(\.start), "The words keep their sync")
        #expect(cue(second.id, in: viewModel) == second, "The neighbor keeps its time")
    }

    @Test func theStartStopsAtTheLineBefore() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let first = line("five dishes", 2, 4), second = line("from São Paulo", 5, 8)
        lay([first, second], on: viewModel)
        viewModel.beginTimelineHandle(.item(.caption, second.id, .start), snapTimes: [])
        let held = viewModel.moveTimelineHandle(by: -3)
        viewModel.endTimelineHandle()
        #expect(held.label == "Stops at the line before")
        #expect(abs((cue(second.id, in: viewModel)?.start ?? 0) - 4) < 0.001)
        #expect(abs((viewModel.captions.editedSpan(ofCaption: second.id)?.start ?? 0) - 4) < 0.001, "The line shows from 4 s")
        #expect(cue(first.id, in: viewModel) == first)
    }

    @Test func oneUndoStepWhenItChangedNoneWhenItWasAlreadyAtTheLimit() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let first = line("five dishes", 7, 9)
        lay([first], on: viewModel)
        let steps = viewModel.document.history.past.count

        viewModel.beginTimelineHandle(.item(.caption, first.id, .end), snapTimes: [])
        _ = viewModel.moveTimelineHandle(by: 0.4)
        _ = viewModel.moveTimelineHandle(by: 3)
        viewModel.endTimelineHandle()
        #expect(viewModel.document.history.past.count == steps + 1, "One step on release")

        viewModel.beginTimelineHandle(.item(.caption, first.id, .end), snapTimes: [])
        let held = viewModel.moveTimelineHandle(by: 2)
        viewModel.endTimelineHandle()
        #expect(held.label == "Stops at the cut")
        #expect(viewModel.document.history.past.count == steps + 1, "Nothing changed: no step")

        viewModel.undo()
        #expect(abs((cue(first.id, in: viewModel)?.end ?? 0) - 9) < 0.001)
    }

    // MARK: - The panel's Start and End

    @Test func thePanelsEndPlusAtTheLimitSaysWhatHoldsIt() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let first = line("five dishes", 7, 10)
        lay([first], on: viewModel)
        let steps = viewModel.document.history.past.count
        viewModel.captions.nudgeCaptionLine(first.id, edge: .end, by: 0.1)
        #expect(scenario.toast.message == "Stops at the cut")
        #expect(viewModel.document.history.past.count == steps)
        #expect(cue(first.id, in: viewModel) == first)

        viewModel.captions.nudgeCaptionLine(first.id, edge: .end, by: -0.1)
        #expect(abs((cue(first.id, in: viewModel)?.end ?? 0) - 9.9) < 0.001, "Shortening still works")
    }
}
