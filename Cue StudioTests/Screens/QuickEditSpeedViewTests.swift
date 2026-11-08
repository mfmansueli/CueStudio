//
//  QuickEditSpeedViewTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Speed's Normal | Curve (owner, canvas 2 F6, 07/11/2026): the two only switch the view, each clip opens on its own, and
/// picking a speed in Normal is what replaces a curve, one undo step, said in a toast.
@MainActor
@Suite("Quick edit · Speed's Normal and Curve are views of each clip")
struct QuickEditSpeedViewTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
    }

    /// Two clips: 0–10 and 10–20, the first picked.
    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
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
        player.seek(to: 2)
        viewModel.clips.selectClipAtPlayhead()
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    private func first(_ viewModel: QuickEditViewModel) -> EditSegment { viewModel.edit.timeline.segments[0] }

    @Test func goingBackToNormalKeepsTheCurve() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.open(.speed))
        viewModel.clips.showSpeedCurves(true)
        viewModel.clips.setSpeedCurve(.hero)
        viewModel.clips.showSpeedCurves(false)
        #expect(first(viewModel).speedCurve?.preset == .hero)
        #expect(!viewModel.clips.showsCurveTab)
        viewModel.clips.showSpeedCurves(true)
        #expect(viewModel.clips.showsCurveTab)
        #expect(first(viewModel).speedCurve?.preset == .hero)
    }

    @Test func pickingASpeedReplacesTheCurveAndUndoBringsItBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.speed))
        viewModel.clips.setSpeedCurve(.hero)
        viewModel.clips.showSpeedCurves(false)
        viewModel.clips.setClipSpeed(1)
        #expect(first(viewModel).speedCurve == nil)
        #expect(scenario.toast.message == String(localized: "Curve replaced by \(SpeedScale.label(forMultiple: 1))"))
        viewModel.undo()
        #expect(first(viewModel).speedCurve?.preset == .hero)
    }

    @Test func eachClipOpensOnItsOwnView() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.speed))
        viewModel.clips.showSpeedCurves(true)
        #expect(viewModel.clips.showsCurveTab)
        // The second clip has no curve and was never switched: it opens on Normal.
        scenario.player.seek(to: 15)
        viewModel.clips.selectClipAtPlayhead()
        #expect(!viewModel.clips.showsCurveTab)
        // A clip with a curve opens on Curve until the creator switches it.
        viewModel.clips.setSpeedCurve(.rampUp)
        viewModel.clips.speedShowsCurve = [:]
        #expect(viewModel.clips.showsCurveTab)
        scenario.player.seek(to: 2)
        viewModel.clips.selectClipAtPlayhead()
        #expect(!viewModel.clips.showsCurveTab)
    }
}
