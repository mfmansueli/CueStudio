//
//  QuickEditEyeContactTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// ✦ Smart › Eye Contact in the editor: off by default, each change one undo step (Off included, a slider drag once), Before never
/// part of the edit, Cancel turning it off and stopping the work, the analysis asked from the playhead (and moved there when a
/// scrub ends), and the draft keeping it.
@MainActor
@Suite("Quick edit Eye Contact")
struct QuickEditEyeContactTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let drafts: FakeDraftStore
        let analyzer: FakeEyeContactAnalyzer
        let eyes: EyeContactAnalysisService
    }

    private func makeScenario(analyzer: FakeEyeContactAnalyzer = FakeEyeContactAnalyzer()) async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let drafts = FakeDraftStore()
        let eyes = EyeContactAnalysisService(analyzer: analyzer)
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: drafts, toast: ToastService(), player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(), eyes: eyes
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, drafts: drafts, analyzer: analyzer, eyes: eyes)
    }

    @Test func itIsOffUntilTurnedOnAndUndoTurnsItOffAgain() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        #expect(!viewModel.eyeContactIsOn)
        #expect(viewModel.smartEyeContactStatus == nil)
        viewModel.toggleEyeContact()
        #expect(viewModel.edit.eyeContact == EyeContactSettings())
        viewModel.undo()
        #expect(viewModel.edit.eyeContact == nil)
        viewModel.redo()
        #expect(viewModel.eyeContactIsOn)
        // Off is a step too.
        viewModel.setEyeContact(false)
        viewModel.undo()
        #expect(viewModel.eyeContactIsOn)
    }

    @Test func aDragOfTheStrengthIsOneStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.setEyeContact(true)
        viewModel.beginChange()
        for value in stride(from: 60.0, through: 90, by: 5) { viewModel.setEyeContactStrength(value) }
        viewModel.endChange()
        #expect(abs(viewModel.eyeContactStrength - 90) < 0.001)
        viewModel.undo()
        #expect(abs(viewModel.eyeContactStrength - EyeContactSettings.defaultStrength * 100) < 0.001)
        viewModel.undo()
        #expect(!viewModel.eyeContactIsOn)
    }

    @Test func resetBringsTheMeasuredStrengthBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.setEyeContact(true)
        viewModel.setEyeContactStrength(35)
        viewModel.resetEyeContactStrength()
        #expect(abs(viewModel.eyeContactStrength - EyeContactSettings.defaultStrength * 100) < 0.001)
    }

    @Test func beforeShowsTheEyesAsFilmedWithoutTouchingTheEdit() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.panel = .eyeContact
        viewModel.setEyeContact(true)
        let canUndo = viewModel.canUndo
        viewModel.toggleEyeContactComparison()
        #expect(viewModel.comparesEyeContact)
        #expect(scenario.player.shown.last?.eyeContact == nil)
        #expect(viewModel.edit.eyeContact != nil)
        #expect(viewModel.canUndo == canUndo)
        // Everything else stays as edited.
        #expect(scenario.player.shown.last?.timeline == viewModel.edit.timeline)
        viewModel.toggleEyeContactComparison()
        #expect(scenario.player.shown.last?.eyeContact != nil)
        // Leaving the panel, or changing the strength, ends it.
        viewModel.toggleEyeContactComparison()
        viewModel.setEyeContactStrength(80)
        #expect(!viewModel.comparesEyeContact)
        viewModel.toggleEyeContactComparison()
        viewModel.panel = nil
        #expect(!viewModel.comparesEyeContact)
        #expect(scenario.player.shown.last?.eyeContact != nil)
    }

    @Test func turningItOnAsksForTheTakeFromThePlayhead() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 4
        viewModel.setEyeContact(true)
        await Wait.until { !scenario.analyzer.calls.isEmpty }
        let call = scenario.analyzer.calls.first
        #expect(call?.0.standardizedFileURL == viewModel.videoURL.standardizedFileURL)
        #expect(call?.1 == 4)
    }

    @Test func scrubbingTheTimelineMovesTheAnalysisWhereThePlayheadStops() async {
        let analyzer = FakeEyeContactAnalyzer(step: .milliseconds(5), holdsAfter: 2)
        let scenario = await makeScenario(analyzer: analyzer)
        let viewModel = scenario.viewModel
        viewModel.setEyeContact(true)
        await Wait.until { scenario.eyes.status(of: viewModel.videoURL)?.progress ?? 0 >= 0.2 }
        viewModel.scrubTimeline(to: 8)
        // While the finger moves, the analysis stays where it was.
        #expect(analyzer.calls.count == 1)
        viewModel.endTimelineScrub()
        await Wait.until { analyzer.calls.count == 2 }
        #expect(analyzer.calls.last?.1 == 8)
        viewModel.cancelEyeContact()
    }

    @Test func cancelTurnsItOffAndStopsTheWork() async {
        let analyzer = FakeEyeContactAnalyzer(step: .milliseconds(5), holdsAfter: 2)
        let scenario = await makeScenario(analyzer: analyzer)
        let viewModel = scenario.viewModel
        viewModel.setEyeContact(true)
        await Wait.until { viewModel.eyeContactState.isWorking }
        viewModel.cancelEyeContact()
        #expect(!viewModel.eyeContactIsOn)
        #expect(viewModel.eyeContactState == .off)
        await Wait.until { scenario.eyes.status(of: viewModel.videoURL) == nil }
    }

    @Test func turnedOffAndOnAgainItAsksAgain() async throws {
        let analyzer = FakeEyeContactAnalyzer(step: .milliseconds(5), holdsAfter: 2)
        let scenario = await makeScenario(analyzer: analyzer)
        let viewModel = scenario.viewModel
        viewModel.setEyeContact(true)
        await Wait.until { scenario.eyes.status(of: viewModel.videoURL)?.progress ?? 0 >= 0.2 }
        viewModel.setEyeContact(false)
        // The run has stopped.
        try await Task.sleep(for: .milliseconds(100))
        viewModel.setEyeContact(true)
        await Wait.until { analyzer.calls.count == 2 }
        #expect(analyzer.calls.count == 2)
        #expect(viewModel.eyeContactState.isWorking)
        viewModel.cancelEyeContact()
    }

    @Test func theDraftKeepsIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.setEyeContact(true)
        viewModel.setEyeContactStrength(75)
        viewModel.saveDraft(forced: true)
        let draft = scenario.drafts.drafts.values.first
        #expect(abs((draft?.edit.eyeContact?.strength ?? 0) - 0.75) < 0.000_1)
        // And what undo needs to turn it off again.
        #expect(draft?.history.canUndo == true)
    }
}
