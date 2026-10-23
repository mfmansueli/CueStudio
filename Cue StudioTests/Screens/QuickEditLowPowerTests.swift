//
//  QuickEditLowPowerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The Low Power Mode notice: only while the mode is on, at most once a day, gone when the mode goes off or ✕ is tapped.
@MainActor
@Suite("QuickEditViewModel Low Power notice")
struct QuickEditLowPowerTests {
    private func makeViewModel(preferences: FakeEditorPreferencesStore) async -> QuickEditViewModel {
        let take = TestData.take(scriptID: nil, number: 3)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(), drafts: FakeDraftStore(),
            toast: ToastService(), player: FakeEditPlayback(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            editorPreferences: preferences
        )
        await viewModel.prepare()
        return viewModel
    }

    private let calendar = Calendar(identifier: .gregorian)

    @Test func theRuleIsWhileOnAndOnceADay() {
        let morning = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(!LowPowerNotice.shows(isLowPower: false, lastShown: nil, now: morning, calendar: calendar))
        #expect(LowPowerNotice.shows(isLowPower: true, lastShown: nil, now: morning, calendar: calendar))
        #expect(!LowPowerNotice.shows(isLowPower: true, lastShown: morning, now: morning.addingTimeInterval(3600), calendar: calendar))
        #expect(LowPowerNotice.shows(isLowPower: true, lastShown: morning, now: morning.addingTimeInterval(86_400), calendar: calendar))
    }

    @Test func itShowsWhileTheModeIsOnAndGoesWhenItIsTurnedOff() async {
        let preferences = FakeEditorPreferencesStore()
        let viewModel = await makeViewModel(preferences: preferences)
        let now = Date()
        viewModel.lowPowerModeChanged(false, now: now)
        #expect(!viewModel.showsLowPowerNotice)
        viewModel.lowPowerModeChanged(true, now: now)
        #expect(viewModel.showsLowPowerNotice)
        #expect(preferences.lowPowerNoticeShownAt == now)
        viewModel.lowPowerModeChanged(false, now: now)
        #expect(!viewModel.showsLowPowerNotice)
        // Back on the same day: not again.
        viewModel.lowPowerModeChanged(true, now: now.addingTimeInterval(60))
        #expect(!viewModel.showsLowPowerNotice)
    }

    @Test func closingItKeepsItAwayForTheDay() async {
        let preferences = FakeEditorPreferencesStore()
        let viewModel = await makeViewModel(preferences: preferences)
        let now = Date()
        viewModel.lowPowerModeChanged(true, now: now)
        viewModel.dismissLowPowerNotice()
        #expect(!viewModel.showsLowPowerNotice)
        viewModel.lowPowerModeChanged(true, now: now.addingTimeInterval(60))
        #expect(!viewModel.showsLowPowerNotice)
        // A new editor on another day says it again.
        let tomorrow = await makeViewModel(preferences: preferences)
        tomorrow.lowPowerModeChanged(true, now: now.addingTimeInterval(86_400 * 2))
        #expect(tomorrow.showsLowPowerNotice)
    }
}
