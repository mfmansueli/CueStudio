//
//  QuickEditLanguageTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What captions and their translation know about languages: the writing system Chinese was heard in,
/// the pairs the system can't translate, and the languages a take couldn't be heard in.
@MainActor
@Suite("Quick edit languages")
struct QuickEditLanguageTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
        let availability: FakeTranslationAvailability
    }

    private func makeScenario(
        text: String = "Okay, real talk.", editor: FakeTakeEditor = FakeTakeEditor(), makesCaptions: Bool = true
    ) async -> Scenario {
        let script = TestData.script(text: text)
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let availability = FakeTranslationAvailability()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            translations: availability
        )
        await viewModel.prepare()
        if makesCaptions {
            viewModel.captions.makeCaptions()
            await viewModel.jobs.finished(.captions)
        }
        return Scenario(viewModel: viewModel, editor: editor, availability: availability)
    }

    private func chineseEditor(code: String, text: String) -> FakeTakeEditor {
        let editor = FakeTakeEditor()
        let words = [CaptionWord(text: text, start: 0, end: 1)]
        editor.captionOutcome = .captions([CaptionCue(words: words)], transcript: CaptionTranscript(words: words, languageCode: code))
        return editor
    }

    // MARK: - The language spoken

    /// A language picked unlike the script's was most likely a slip: the first seconds are heard in both, and the picker then says
    /// the one the captions were heard in.
    @Test func aLanguagePickedUnlikeTheScriptsIsCheckedAgainstIt() async {
        let editor = FakeTakeEditor()
        let words = [CaptionWord(text: "Okay,", start: 0, end: 0.4), CaptionWord(text: "real", start: 0.4, end: 0.7)]
        editor.captionOutcome = .captions([CaptionCue(words: words)], transcript: CaptionTranscript(words: words, languageCode: "en"))
        let scenario = await makeScenario(editor: editor, makesCaptions: false)
        let viewModel = scenario.viewModel
        viewModel.captions.setCaptionLanguage(.portugueseBrazil)
        viewModel.captions.makeCaptions()
        await viewModel.jobs.finished(.captions)
        #expect(editor.captionCandidates == [.english, .portugueseBrazil])
        #expect(viewModel.edit.captionLanguage == .english)
        // Now picked like the script's: what was heard is used again, nothing is compared.
        viewModel.captions.makeCaptions(replacingRevised: true)
        await viewModel.jobs.finished(.captions)
        #expect(editor.captionRequests == 1)
    }

    // MARK: - The writing system Chinese was heard in

    @Test func traditionalChineseCaptionsAreTranslatedFromTraditionalNotSimplified() async {
        let scenario = await makeScenario(editor: chineseEditor(code: "zh-Hant", text: "這是改變我早晨的三個習慣。"))
        let source = scenario.viewModel.captions.captionSourceLanguage
        #expect(source?.languageCode?.identifier == "zh")
        #expect(source?.script?.identifier == "Hant")
    }

    /// A transcript kept before Chinese carried its writing system says only "zh": the lines show it.
    @Test func anOlderChineseTranscriptTakesItsWritingSystemFromTheLines() async {
        let scenario = await makeScenario(editor: chineseEditor(code: "zh", text: "這是改變我早晨的三個習慣。第一，我在看手機之前先喝一杯水。"))
        #expect(scenario.viewModel.captions.captionSourceLanguage?.script?.identifier == "Hant")
        let simplified = await makeScenario(editor: chineseEditor(code: "zh", text: "这是改变我早晨的三个习惯。第一，我在看手机之前先喝一杯水。"))
        #expect(simplified.viewModel.captions.captionSourceLanguage?.script?.identifier == "Hans")
    }

    @Test func chineseIsNeverOfferedAsATargetForChineseCaptions() async {
        let scenario = await makeScenario(editor: chineseEditor(code: "zh-Hant", text: "這是改變我早晨的三個習慣。"))
        let targets = scenario.viewModel.captions.translationTargets
        #expect(!targets.contains(.chineseSimplified) && !targets.contains(.chineseTraditional))
        #expect(targets.contains(.english))
    }

    // MARK: - A pair the system can't translate

    @Test func aPairTheSystemRefusesMidwayIsSaidNotCalledAFailure() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await viewModel.captions.translateCaptions(to: .thai)
        let session = FakeTranslationSession()
        session.error = CaptionTranslationError.unsupportedPair
        await viewModel.captions.performTranslation(try #require(viewModel.captions.translationRequest), with: session)
        guard case .unsupported(_, let target) = viewModel.captions.translationState else {
            Issue.record("Expected an unsupported pair, got \(viewModel.captions.translationState)")
            return
        }
        #expect(target == .thai)
        #expect(viewModel.captions.translation(.thai) == nil)
    }

    @Test func anotherFailureIsStillATryAgain() async throws {
        let scenario = await makeScenario()
        await scenario.viewModel.captions.translateCaptions(to: .german)
        let session = FakeTranslationSession()
        session.error = URLError(.notConnectedToInternet)
        await scenario.viewModel.captions.performTranslation(try #require(scenario.viewModel.captions.translationRequest), with: session)
        #expect(scenario.viewModel.captions.translationState == .failed)
    }

    // MARK: - Languages a take couldn't be heard in

    @Test func captionsToldWhenALanguageOfTheScriptWasNotHeard() async {
        let editor = FakeTakeEditor()
        let words = [CaptionWord(text: "Bom", start: 0, end: 0.3), CaptionWord(text: "dia.", start: 0.35, end: 0.7)]
        editor.captionOutcome = .captions(
            [CaptionCue(words: words)],
            transcript: CaptionTranscript(words: words, languageCode: "pt", unheardLanguages: ["en"])
        )
        let scenario = await makeScenario(editor: editor)
        #expect(scenario.viewModel.captions.captionState == .missingLanguages(["en"]))
        #expect(scenario.viewModel.captions.captionState.canRetry)
        let message = scenario.viewModel.captions.captionState.message
        #expect(message?.contains(Locale.interface.localizedString(forLanguageCode: "en") ?? "English") == true)
        // The lines that were heard are still there.
        #expect(scenario.viewModel.edit.captions.count == 1)
    }

    @Test func captionsHeardInEveryLanguageSayNothingMore() async {
        let scenario = await makeScenario()
        #expect(scenario.viewModel.captions.captionState == .idle)
        #expect(scenario.viewModel.captions.captionState.message == nil)
    }

    @Test func severalMissingLanguagesAreNamedTogether() {
        let message = CaptionState.missingLanguages(["en", "es"]).message
        #expect(message?.contains(Locale.interface.localizedString(forLanguageCode: "en") ?? "") == true)
        #expect(message?.contains(Locale.interface.localizedString(forLanguageCode: "es") ?? "") == true)
    }

    @Test func aTranscriptWithoutUnheardLanguagesKeepsItsOldShape() throws {
        let transcript = CaptionTranscript(words: [CaptionWord(text: "Oi", start: 0, end: 1)], languageCode: "pt")
        let data = try JSONEncoder().encode(transcript)
        let decoded = try JSONDecoder().decode(CaptionTranscript.self, from: data)
        #expect(decoded.unheardLanguages == nil)
        // A transcript saved before the field existed still opens.
        let old = Data(#"{"words":[],"languageCode":"en"}"#.utf8)
        #expect(try JSONDecoder().decode(CaptionTranscript.self, from: old).unheardLanguages == nil)
    }
}
