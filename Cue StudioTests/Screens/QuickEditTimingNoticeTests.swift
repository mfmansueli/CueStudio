//
//  QuickEditTimingNoticeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A correction that has to guess times says so (E4, "Avisar quando uma correção mexe no tempo"): typed words with no voice under
/// them, Replace and Replace all, and a split by length; a correction that keeps the voice's times says nothing about timing.
@MainActor
struct QuickEditTimingNoticeTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let toast: ToastService
    }

    /// Two words said back to back, too short to give room to new words between them.
    private let tight = CaptionCue(
        text: "hi there", start: 1, end: 1.1,
        words: [
            CaptionWord(text: "hi", start: 1, end: 1.05, isEstimated: false),
            CaptionWord(text: "there", start: 1.05, end: 1.1, isEstimated: false),
        ],
        origin: .speech
    )
    /// A line timed as a whole.
    private let whole = CaptionCue(text: "a line timed whole", start: 3, end: 5, origin: .manual)

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
            $0.captions = [tight, whole]
            $0.showsCaptions = true
        }
        return Scenario(viewModel: viewModel, toast: toast)
    }

    @Test func typedWordsWithNoVoiceUnderThemSaySo() async throws {
        let scenario = await makeScenario()
        scenario.viewModel.captions.setCaptionText(tight.id, "hi there")
        #expect(scenario.toast.message == nil, "Nothing guessed")
        scenario.viewModel.captions.setCaptionText(tight.id, "hi big new there")
        #expect(scenario.viewModel.edit.captions.first?.needsTimingReview == true)
        #expect(scenario.toast.message == "Timing guessed in 1 line · Check timing")
    }

    @Test func replaceAllSaysHowManyLinesToCheck() async throws {
        let scenario = await makeScenario()
        scenario.viewModel.captions.replaceAllCaptionMatches("hi there", with: "hi big new there")
        #expect(scenario.toast.message?.hasSuffix(" · Timing guessed in 1 line · Check timing") == true, "\(scenario.toast.message ?? "")")
    }

    @Test func aSplitByLengthSaysSo() async throws {
        let scenario = await makeScenario()
        scenario.viewModel.captions.splitCaption(whole.id, beforeWord: 2)
        #expect(scenario.toast.message == "Timing guessed in 2 lines · Check timing")
    }
}
