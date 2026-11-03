//
//  ScriptPageTypingTests.swift
//  Cue StudioTests
//

import Foundation
import Observation
import os
import Testing
@testable import Cue_Studio

/// Typing in a script's words must be as fluid as in Notes, whatever the script's length (the owner, 03/11/2026: a long script the AI wrote
/// lagged where a short one of the creator's didn't). A letter costs the editor only: the page around the words (the strip, the length, the
/// tools, the language) keeps what it measured when the typing began, and catches up once it pauses.
@MainActor
@Suite("Typing on the script page")
struct ScriptPageTypingTests {
    private func makeViewModel(text: String, defaults: TestDefaults) -> ScriptDetailViewModel {
        let script = TestData.script(text: text, platform: .youtube, isFinished: false)
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: []))
        takes.load()
        return ScriptDetailViewModel(
            scriptID: script.id, startsEditing: true, writing: nil, revealPause: .zero,
            library: library, takes: takes, preferences: PreferencesService(defaults: defaults.defaults),
            profile: CreatorProfileService(defaults: defaults.defaults), rules: TestData.rulesService(), writer: FakeScriptWriter(),
            toast: ToastService()
        )
    }

    /// A letter as the editor reports it (`ScriptTextViewRepresentable`): the words, then the page told.
    private func type(_ letter: Character, into viewModel: ScriptDetailViewModel) {
        viewModel.page.type(viewModel.page.text + String(letter))
        viewModel.wordsTyped()
    }

    /// Everything `ScriptPageView` reads to draw the page around the words.
    private func readAsThePageDoes(_ viewModel: ScriptDetailViewModel) {
        _ = viewModel.script
        _ = viewModel.strip
        _ = viewModel.measuredText
        _ = viewModel.zone
        _ = viewModel.blocks
        _ = viewModel.hookOverrun
        _ = viewModel.offersImprove
        _ = viewModel.canDraft
        _ = viewModel.translationLanguages
        _ = viewModel.needsFactCheck
        _ = viewModel.showsVoicePreview
        _ = viewModel.previewedText
        _ = viewModel.isTouchingUp
        _ = viewModel.runningTool
        _ = viewModel.showsSelectionBar
        _ = viewModel.showsCues
        _ = viewModel.scriptTakes
        _ = (viewModel.page.isWriting, viewModel.page.passage, viewModel.page.textSize, viewModel.page.selection, viewModel.page.isRewriting)
        _ = (viewModel.page.isEmpty, viewModel.page.revealed, viewModel.page.isEdited, viewModel.page.isDone)
    }

    @Test func aLetterTypedLeavesThePageAroundTheWordsAlone() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let viewModel = makeViewModel(text: SampleAIDraft.text, defaults: defaults)
        // The visit's first edit makes the script edited (the strip says so, once), and the typing pauses.
        type(" ", into: viewModel)
        viewModel.page.catchUp()
        let redrawn = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            readAsThePageDoes(viewModel)
        } onChange: {
            redrawn.withLock { $0 = true }
        }
        // From the first letter after the pause on: none of them redraws the page (it catches up once, at the next pause).
        for letter in "and more" { type(letter, into: viewModel) }
        #expect(!redrawn.withLock { $0 }, "A letter typed redrew the page around the words")
        #expect(viewModel.page.text.hasSuffix(" and more"))
        #expect(viewModel.measuredText == SampleAIDraft.text + " ")
    }

    @Test func thePageCatchesUpWhenTheTypingPauses() async throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let viewModel = makeViewModel(text: "Okay, so I did cold showers for thirty days.", defaults: defaults)
        for letter in " Day one was rough." { type(letter, into: viewModel) }
        #expect(viewModel.zone.words == 9)
        // The pause, and room for a busy main actor (the other suites run alongside).
        for _ in 0..<30 where viewModel.measuredText != viewModel.page.text {
            try await Task.sleep(for: ScriptDetailViewModel.typingPause / 3)
        }
        #expect(viewModel.measuredText == viewModel.page.text)
        #expect(viewModel.zone.words == 13)
    }

    @Test func theLanguageIsReadAgainWhenTheWordsChangeLanguage() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let viewModel = makeViewModel(text: SampleAIDraft.text, defaults: defaults)
        #expect(!viewModel.translationLanguages.contains(.portugueseBrazil))
        // Typing on keeps the language read once.
        for letter in " e mais uma frase" { type(letter, into: viewModel) }
        viewModel.page.catchUp()
        #expect(!viewModel.translationLanguages.contains(.portugueseBrazil))
        // The words now in English (pasted over them, a translation): read again.
        viewModel.page.text = String(repeating: "I woke up at five every day for a month, and here is everything that happened to me. ", count: 50)
        #expect(!viewModel.translationLanguages.contains(.english))
        #expect(viewModel.translationLanguages.contains(.portugueseBrazil))
    }
}
