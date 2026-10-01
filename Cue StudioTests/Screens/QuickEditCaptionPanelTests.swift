//
//  QuickEditCaptionPanelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The Captions and Caption style panels: a line tapped goes to its time and is picked, its edges
/// move in tenths without crossing a neighbor (taking the playhead along), a line is only added in
/// a free gap, and the look changes for every line.
@MainActor
@Suite("Quick edit caption panels")
struct QuickEditCaptionPanelTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
    }

    private func makeScenario(lines: [(TimeInterval, TimeInterval, String)]) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.edit.captions = lines.map { CaptionCue(text: $0.2, start: $0.0, end: $0.1) }
        viewModel.edit.showsCaptions = true
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    @Test func aLineTappedInTheListIsPickedAndShown() async {
        let scenario = await makeScenario(lines: [(0.3, 2.3, "Comidas de SP"), (2.3, 4, "que são só pra turista.")])
        let line = scenario.viewModel.captionListLines[1]
        scenario.viewModel.pickCaptionLine(line.cueID, at: line.line.start)
        #expect(scenario.viewModel.selection == .caption(line.cueID))
        #expect(abs(scenario.player.currentTime - 2.31) < 0.001)
        #expect(scenario.viewModel.activeCaptionCueID == line.cueID)
    }

    @Test func nudgingAnEdgeNeverCrossesTheNeighborAndShowsIt() async {
        let scenario = await makeScenario(lines: [(0, 2, "First"), (2.5, 4, "Second")])
        let viewModel = scenario.viewModel
        let first = viewModel.captionListLines[0].cueID
        let steps = viewModel.history.past.count
        for _ in 0..<10 { viewModel.nudgeCaptionLine(first, edge: .end, by: 0.1) }
        let end = viewModel.editedSpan(ofCaption: first)?.end ?? 0
        #expect(abs(end - 2.5) < 0.001)
        // The playhead shows the line's last moments.
        #expect(abs(scenario.player.currentTime - 2.2) < 0.001)
        // Quick taps are one undo step.
        #expect(viewModel.history.past.count == steps + 1)
        let second = viewModel.captionListLines[1].cueID
        viewModel.nudgeCaptionLine(second, edge: .start, by: -0.1)
        #expect(abs((viewModel.editedSpan(ofCaption: second)?.start ?? 0) - 2.5) < 0.001)
        viewModel.nudgeCaptionLine(second, edge: .start, by: 0.1)
        #expect(abs((viewModel.editedSpan(ofCaption: second)?.start ?? 0) - 2.6) < 0.001)
        #expect(abs(scenario.player.currentTime - 2.61) < 0.001)
    }

    @Test func aLineIsAddedOnlyInAFreeGap() async {
        let scenario = await makeScenario(lines: [(0, 2, "First"), (3, 5, "Second"), (5.2, 6, "Third")])
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 1)
        viewModel.addCaptionAtPlayhead()
        #expect(viewModel.edit.captions.count == 3)
        #expect(scenario.toast.message == "There is a line here — move to a gap")
        scenario.player.seek(to: 5.05)
        viewModel.addCaptionAtPlayhead()
        #expect(viewModel.edit.captions.count == 3)
        #expect(scenario.toast.message == "Not enough room here")
        scenario.player.seek(to: 2.2)
        viewModel.addCaptionAtPlayhead()
        #expect(viewModel.edit.captions.count == 4)
        let added = viewModel.editedCaptionLines.first { abs($0.start - 2.2) < 0.001 }
        // Up to the next line, shorter than the usual 1.6 s.
        #expect(abs((added?.end ?? 0) - 3) < 0.001)
        #expect(added?.text == "New line")
        #expect(viewModel.selection == added.map { .caption($0.id) })
        #expect(viewModel.focusesCaptionField)
    }

    @Test func theSwitchHidesAndShowsTheLines() async {
        let scenario = await makeScenario(lines: [(0, 2, "First")])
        scenario.viewModel.toggleCaptions()
        #expect(!scenario.viewModel.edit.showsCaptions)
        scenario.viewModel.toggleCaptions()
        #expect(scenario.viewModel.edit.showsCaptions)
    }

    @Test func withoutLinesTheSwitchOpensAutoCaptions() async {
        let scenario = await makeScenario(lines: [])
        scenario.viewModel.toggleCaptions()
        #expect(scenario.viewModel.panel == .autoCaptions)
    }

    @Test func revealSetsWhetherLinesFollowTheWords() async {
        let scenario = await makeScenario(lines: [(0, 2, "First")])
        let viewModel = scenario.viewModel
        #expect(viewModel.edit.captionCollection != nil)
        viewModel.pickCaptionReveal(.line)
        #expect(viewModel.captionReveal == .line)
        #expect(viewModel.edit.captionCollection?.followsWords == false)
        viewModel.pickCaptionReveal(.fade)
        #expect(viewModel.captionReveal == .fade)
        viewModel.pickCaptionReveal(.box)
        #expect(viewModel.captionReveal == .box)
        #expect(viewModel.edit.captionCollection?.followsWords == true)
        viewModel.pickCaptionReveal(.groups)
        #expect(viewModel.captionReveal == .groups)
        // A preset keeps the reveal picked.
        viewModel.pickCaptionTheme(.pop)
        #expect(viewModel.captionTheme == .pop)
        #expect(viewModel.captionReveal == .groups)
    }

    @Test func positionAndSizeChangeEveryLine() async {
        let scenario = await makeScenario(lines: [(0, 2, "First")])
        let viewModel = scenario.viewModel
        viewModel.setCaptionPositionStop(.top)
        #expect(viewModel.captionY == 0.16)
        #expect(viewModel.captionPositionStop == .top)
        viewModel.setCaptionPositionStop(.middle)
        #expect(viewModel.captionPositionStop == .middle)
        viewModel.setCaptionPointSize(20)
        #expect(viewModel.captionPointSize == 20)
        viewModel.setCaptionPointSize(40)
        #expect(viewModel.captionPointSize == 28)
    }

    @Test func aTranslationAlreadyMadeShowsAtOnce() async {
        let scenario = await makeScenario(lines: [(0, 2, "Primeiro")])
        let viewModel = scenario.viewModel
        viewModel.writeTranslation(.english)
        await viewModel.pickCaptionTranslation(.english)
        #expect(viewModel.edit.captionDisplay == .translation(.english))
        #expect(viewModel.captionTranslationLabel == CueLanguage.english.nativeName)
        await viewModel.pickCaptionTranslation(nil)
        #expect(viewModel.edit.captionDisplay == .original)
        #expect(viewModel.captionTranslationLabel == "Translate")
    }
}
