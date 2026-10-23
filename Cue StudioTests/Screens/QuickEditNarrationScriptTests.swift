//
//  QuickEditNarrationScriptTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Voice-over's "Show script": offered only with a script, remembered between edits, started with the recording, never past it.
@MainActor
@Suite("QuickEditViewModel narration script")
struct QuickEditNarrationScriptTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let preferences: FakeEditorPreferencesStore
        let recorder: FakeVoiceRecorder
    }

    private func makeScenario(
        script: Script? = TestData.script(text: "Okay, real talk. [pause] Three tiny habits.\n\nNumber one: water."),
        preferences: FakeEditorPreferencesStore = FakeEditorPreferencesStore(),
        prompterLook: PrompterSettings = PrompterSettings()
    ) async -> Scenario {
        let take = TestData.take(scriptID: script?.id, number: 3)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: script.map { [$0] } ?? []))
        library.load()
        let recorder = FakeVoiceRecorder()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(), drafts: FakeDraftStore(),
            toast: ToastService(), player: FakeEditPlayback(), recorder: recorder, styles: FakeTextStyleStore(),
            editorPreferences: preferences, prompterLook: prompterLook
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, preferences: preferences, recorder: recorder)
    }

    @Test func aTakeWithAScriptOffersItWithoutItsCues() async {
        let scenario = await makeScenario()
        #expect(scenario.viewModel.offersNarrationScript)
        #expect(scenario.viewModel.narrationScriptText?.contains("[pause]") == false)
        #expect(scenario.viewModel.narrationScriptText?.hasPrefix("Okay, real talk.") == true)
        scenario.viewModel.panel = .voiceOver
        #expect(scenario.viewModel.showsNarrationScriptOverlay)
        // Record, the switch and the speed need the medium panel.
        #expect(scenario.viewModel.openPanelSize == .medium)
    }

    @Test func aFreestyleTakeOffersNothingNew() async {
        let scenario = await makeScenario(script: nil)
        #expect(!scenario.viewModel.offersNarrationScript)
        scenario.viewModel.panel = .voiceOver
        #expect(!scenario.viewModel.showsNarrationScriptOverlay)
        #expect(scenario.viewModel.openPanelSize == .mini)
    }

    @Test func anEmptyScriptOffersNothing() async {
        let scenario = await makeScenario(script: TestData.script(text: "  [smile]  \n\n"))
        #expect(!scenario.viewModel.offersNarrationScript)
    }

    @Test func theSwitchIsRememberedForTheNextEdit() async {
        let scenario = await makeScenario()
        scenario.viewModel.panel = .voiceOver
        scenario.viewModel.toggleNarrationScript()
        #expect(!scenario.viewModel.showsNarrationScript)
        #expect(!scenario.preferences.showsNarrationScript)
        #expect(!scenario.viewModel.showsNarrationScriptOverlay)
        let next = await makeScenario(preferences: scenario.preferences)
        #expect(!next.viewModel.showsNarrationScript)
    }

    @Test func onlyVoiceOverShowsIt() async {
        let scenario = await makeScenario()
        scenario.viewModel.panel = .volume
        #expect(!scenario.viewModel.showsNarrationScriptOverlay)
        scenario.viewModel.panel = nil
        #expect(!scenario.viewModel.showsNarrationScriptOverlay)
    }

    @Test func itReadsAtThePrompterSpeedUnlessTheCreatorPickedAnother() async {
        var look = PrompterSettings()
        look.speed = PrompterSettings.clampedSpeed(ReadTime.naturalSpeed * 1.5)
        let fromPrompter = await makeScenario(prompterLook: look)
        #expect(fromPrompter.viewModel.narrationPace.speed == look.speed)
        let picked = PrompterSettings.clampedSpeed(ReadTime.naturalSpeed * 0.6)
        let fromEditor = await makeScenario(preferences: FakeEditorPreferencesStore(narrationScriptSpeed: picked), prompterLook: look)
        #expect(fromEditor.viewModel.narrationPace.speed == picked)
    }

    @Test func aNewSpeedIsRemembered() async {
        let scenario = await makeScenario()
        let faster = PrompterSettings.clampedSpeed(ReadTime.naturalSpeed * 1.4)
        scenario.viewModel.setNarrationSpeed(faster)
        #expect(scenario.viewModel.narrationPace.speed == faster)
        #expect(scenario.preferences.narrationScriptSpeed == faster)
    }

    @Test func theScriptStartsWithTheRecordingAndGoesBackToTheStartAfter() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.panel = .voiceOver
        // Before recording a tap holds nothing.
        viewModel.toggleNarrationPause()
        #expect(viewModel.narrationPace.phase == .waiting)
        await viewModel.startVoiceOver()
        #expect(viewModel.narrationPace.isReading)
        viewModel.toggleNarrationPause()
        #expect(viewModel.narrationPace.isPaused)
        viewModel.toggleNarrationPause()
        #expect(viewModel.narrationPace.isReading)
        viewModel.stopVoiceOver()
        #expect(viewModel.narrationPace.phase == .waiting)
        // Nothing of the script goes into the edit: only the narration.
        #expect(viewModel.edit.voiceOvers.count == 1)
        #expect(viewModel.edit.texts.isEmpty)
    }

    @Test func cancellingARecordingResetsTheScript() async {
        let scenario = await makeScenario()
        scenario.viewModel.panel = .voiceOver
        await scenario.viewModel.startVoiceOver()
        scenario.viewModel.cancelVoiceOver()
        #expect(scenario.viewModel.narrationPace.phase == .waiting)
        #expect(scenario.recorder.cancelled)
    }

    @Test func theLookIsThePrompterOnesWithoutCues() async {
        var look = PrompterSettings()
        look.font = .lexend
        look.textColor = .yellow
        look.showsCues = true
        let scenario = await makeScenario(prompterLook: look)
        #expect(scenario.viewModel.narrationLook.textColor == .yellow)
        #expect(scenario.viewModel.narrationLook.font == .lexend)
        #expect(!scenario.viewModel.narrationLook.showsCues)
    }
}
