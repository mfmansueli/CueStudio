//
//  QuickEditTranslationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Translating captions in Quick edit: asked for each pair, never invented when a pair isn't
/// supported, written by hand instead, corrected, outdated when the original changes, and shown as
/// original, translation or both.
@MainActor
@Suite("Quick edit translation")
struct QuickEditTranslationTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let availability: FakeTranslationAvailability
        let toast: ToastService
    }

    private func makeScenario() async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let availability = FakeTranslationAvailability()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            translations: availability
        )
        await viewModel.prepare()
        viewModel.captions.makeCaptions()
        await viewModel.jobs.finished(.captions)
        return Scenario(viewModel: viewModel, availability: availability, toast: toast)
    }

    /// Lines of the Spanish translation whose original changed since (what the Translate sheet marks).
    private func outdatedSpanish(_ viewModel: QuickEditViewModel) -> [TranslatedCaptionLine] {
        viewModel.captions.translation(.spanish)?.outdatedLines(against: viewModel.edit.captions) ?? []
    }

    @Test func captionsAreTranslatedSentenceBySentenceAsOneStep() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let steps = viewModel.document.history.past.count
        await viewModel.captions.translateCaptions(to: .portugueseBrazil)
        #expect(viewModel.captions.translationState == .translating)
        let request = try #require(viewModel.captions.translationRequest)
        let session = FakeTranslationSession()
        await viewModel.captions.performTranslation(request, with: session)
        #expect(session.asked == ["Okay, real talk."])
        #expect(viewModel.captions.translation(.portugueseBrazil)?.lines.map(\.text) == ["EN Okay, real talk."])
        #expect(viewModel.captions.translationState == .idle)
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(scenario.toast.message?.hasPrefix("Translated to") == true)
        // The original lines are untouched.
        #expect(viewModel.edit.captions.map(\.text) == ["Okay, real talk."])
    }

    @Test func anUnsupportedPairIsSaidAndCanBeWrittenByHand() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.availability.support = .unsupported
        await viewModel.captions.translateCaptions(to: .thai)
        #expect(viewModel.captions.translationRequest == nil)
        if case .unsupported(_, let target) = viewModel.captions.translationState {
            #expect(target == .thai)
        } else {
            Issue.record("Expected unsupported, got \(viewModel.captions.translationState)")
        }
        viewModel.captions.writeTranslation(.thai)
        let lines = viewModel.captions.translation(.thai)?.lines ?? []
        #expect(lines.count == 1)
        #expect(lines[0].text.isEmpty)
        viewModel.captions.setTranslatedText(.thai, line: lines[0].id, "เอาล่ะ พูดกันตรงๆ")
        #expect(viewModel.captions.translation(.thai)?.lines[0].isRevised == true)
    }

    @Test func aStoppedOrReplacedRequestLeavesNothingBehind() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.captions.translateCaptions(to: .french)
        let request = try #require(viewModel.captions.translationRequest)
        viewModel.captions.cancelTranslation()
        await viewModel.captions.performTranslation(request, with: FakeTranslationSession())
        #expect(viewModel.captions.translation(.french) == nil)
        #expect(viewModel.captions.translationState == .idle)
    }

    @Test func aFailedTranslationCanBeTriedAgain() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.captions.translateCaptions(to: .german)
        let session = FakeTranslationSession()
        session.fails = true
        await viewModel.captions.performTranslation(try #require(viewModel.captions.translationRequest), with: session)
        #expect(viewModel.captions.translationState == .failed)
        #expect(viewModel.captions.translation(.german) == nil)
    }

    @Test func changingTheOriginalMarksTheTranslationOutdated() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.captions.translateCaptions(to: .spanish)
        await viewModel.captions.performTranslation(try #require(viewModel.captions.translationRequest), with: FakeTranslationSession())
        #expect(outdatedSpanish(viewModel).isEmpty)
        viewModel.captions.setCaptionText(viewModel.edit.captions[0].id, "Okay, so real talk.")
        let outdated = outdatedSpanish(viewModel)
        #expect(outdated.count == 1)
        // The correction isn't thrown away: the line is still there, marked.
        #expect(viewModel.captions.translation(.spanish)?.lines.count == 1)
        viewModel.captions.markTranslationCurrent(.spanish, line: outdated[0].id)
        #expect(outdatedSpanish(viewModel).isEmpty)
    }

    @Test func theDisplayChoosesWhatShowsAndGoesBackWithItsTranslation() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.captions.translateCaptions(to: .italian)
        await viewModel.captions.performTranslation(try #require(viewModel.captions.translationRequest), with: FakeTranslationSession())
        viewModel.captions.setCaptionDisplay(.bilingual(.italian))
        #expect(viewModel.edit.shownCaptions.second.count == 1)
        viewModel.captions.deleteTranslation(.italian)
        #expect(viewModel.edit.captionDisplay == .original)
        viewModel.undo()
        #expect(viewModel.edit.captionDisplay == .bilingual(.italian))
        #expect(viewModel.captions.translation(.italian) != nil)
    }

    @Test func theCaptionsOwnLanguageIsNotATarget() async {
        let scenario = await makeScenario()
        // The fake heard English.
        #expect(!scenario.viewModel.captions.translationTargets.contains(.english))
        #expect(scenario.viewModel.captions.translationTargets.contains(.japanese))
    }
}
