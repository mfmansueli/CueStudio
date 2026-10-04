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
        viewModel.makeCaptions()
        await viewModel.captionTask?.value
        return Scenario(viewModel: viewModel, availability: availability, toast: toast)
    }

    @Test func captionsAreTranslatedSentenceBySentenceAsOneStep() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let steps = viewModel.history.past.count
        await viewModel.translateCaptions(to: .portugueseBrazil)
        #expect(viewModel.translationState == .translating)
        let request = try #require(viewModel.translationRequest)
        let session = FakeTranslationSession()
        await viewModel.performTranslation(request, with: session)
        #expect(session.asked == ["Okay, real talk."])
        #expect(viewModel.translation(.portugueseBrazil)?.lines.map(\.text) == ["EN Okay, real talk."])
        #expect(viewModel.translationState == .idle)
        #expect(viewModel.history.past.count == steps + 1)
        #expect(scenario.toast.message?.hasPrefix("Translated to") == true)
        // The original lines are untouched.
        #expect(viewModel.edit.captions.map(\.text) == ["Okay, real talk."])
    }

    @Test func anUnsupportedPairIsSaidAndCanBeWrittenByHand() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.availability.support = .unsupported
        await viewModel.translateCaptions(to: .thai)
        #expect(viewModel.translationRequest == nil)
        if case .unsupported(_, let target) = viewModel.translationState {
            #expect(target == .thai)
        } else {
            Issue.record("Expected unsupported, got \(viewModel.translationState)")
        }
        viewModel.writeTranslation(.thai)
        let lines = viewModel.translation(.thai)?.lines ?? []
        #expect(lines.count == 1)
        #expect(lines[0].text.isEmpty)
        viewModel.setTranslatedText(.thai, line: lines[0].id, "เอาล่ะ พูดกันตรงๆ")
        #expect(viewModel.translation(.thai)?.lines[0].isRevised == true)
    }

    @Test func aStoppedOrReplacedRequestLeavesNothingBehind() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.translateCaptions(to: .french)
        let request = try #require(viewModel.translationRequest)
        viewModel.cancelTranslation()
        await viewModel.performTranslation(request, with: FakeTranslationSession())
        #expect(viewModel.translation(.french) == nil)
        #expect(viewModel.translationState == .idle)
    }

    @Test func aFailedTranslationCanBeTriedAgain() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.translateCaptions(to: .german)
        let session = FakeTranslationSession()
        session.fails = true
        await viewModel.performTranslation(try #require(viewModel.translationRequest), with: session)
        #expect(viewModel.translationState == .failed)
        #expect(viewModel.translation(.german) == nil)
    }

    @Test func changingTheOriginalMarksTheTranslationOutdated() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.translateCaptions(to: .spanish)
        await viewModel.performTranslation(try #require(viewModel.translationRequest), with: FakeTranslationSession())
        #expect(viewModel.outdatedLines(.spanish).isEmpty)
        viewModel.setCaptionText(viewModel.edit.captions[0].id, "Okay, so real talk.")
        let outdated = viewModel.outdatedLines(.spanish)
        #expect(outdated.count == 1)
        // The correction isn't thrown away: the line is still there, marked.
        #expect(viewModel.translation(.spanish)?.lines.count == 1)
        viewModel.markTranslationCurrent(.spanish, line: outdated[0].id)
        #expect(viewModel.outdatedLines(.spanish).isEmpty)
    }

    @Test func theDisplayChoosesWhatShowsAndGoesBackWithItsTranslation() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.translateCaptions(to: .italian)
        await viewModel.performTranslation(try #require(viewModel.translationRequest), with: FakeTranslationSession())
        viewModel.setCaptionDisplay(.bilingual(.italian))
        #expect(viewModel.edit.shownCaptions.second.count == 1)
        viewModel.deleteTranslation(.italian)
        #expect(viewModel.edit.captionDisplay == .original)
        viewModel.undo()
        #expect(viewModel.edit.captionDisplay == .bilingual(.italian))
        #expect(viewModel.translation(.italian) != nil)
    }

    @Test func theCaptionsOwnLanguageIsNotATarget() async {
        let scenario = await makeScenario()
        // The fake heard English.
        #expect(!scenario.viewModel.translationTargets.contains(.english))
        #expect(scenario.viewModel.translationTargets.contains(.japanese))
    }
}
