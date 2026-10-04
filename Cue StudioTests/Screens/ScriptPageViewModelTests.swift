//
//  ScriptPageViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import SwiftUI
import Testing
@testable import Cue_Studio

/// The script page: Draft and Shaped over one set of words, saved as the creator writes, and the AI
/// writing into it.
@MainActor
@Suite("Script page")
struct ScriptPageViewModelTests {
    private struct Scenario {
        let viewModel: ScriptDetailViewModel
        let library: ScriptLibraryService
        let writer: FakeScriptWriter
        let toast: ToastService
        let profile: CreatorProfileService
        let ideaDraft: IdeaDraftService
        let defaults: TestDefaults
    }

    private func makeScenario(
        script: Script = TestData.script(), takeCount: Int = 0, startsEditing: Bool = false, writing: ScriptRequest? = nil
    ) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: (0..<takeCount).map {
            TestData.take(scriptID: script.id, number: $0 + 1)
        }))
        takes.load()
        let writer = FakeScriptWriter()
        let toast = ToastService()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        let ideaDraft = IdeaDraftService()
        let viewModel = ScriptDetailViewModel(
            scriptID: script.id, startsEditing: startsEditing, writing: writing, ideaDraft: ideaDraft, revealPause: .zero,
            library: library, takes: takes, preferences: PreferencesService(defaults: defaults.defaults), profile: profile,
            rules: TestData.rulesService(), writer: writer, toast: toast
        )
        return Scenario(viewModel: viewModel, library: library, writer: writer, toast: toast, profile: profile, ideaDraft: ideaDraft, defaults: defaults)
    }

    private func request(voice: CreatorVoice? = nil) -> ScriptRequest {
        ScriptRequest(source: .prompt("Carnival in Salvador"), platform: .reels, tone: nil, voice: voice, targetRange: 30...60)
    }

    // MARK: - Opening

    @Test func aScriptWithWordsOpensShapedAndANewOneOpensInTheDraft() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.page.isLoaded && scenario.viewModel.page.mode == .shaped)
        let blank = makeScenario(script: TestData.script(title: "", text: ""))
        defer { blank.defaults.tearDown() }
        #expect(blank.viewModel.page.mode == .draft && blank.viewModel.page.focusesTitle)
        let imported = makeScenario(startsEditing: true)
        defer { imported.defaults.tearDown() }
        #expect(imported.viewModel.page.mode == .draft && !imported.viewModel.page.focusesTitle)
    }

    @Test func switchingFacesNeverChangesTheWords() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let text = scenario.viewModel.page.text
        scenario.viewModel.setMode(.draft)
        scenario.viewModel.shape()
        #expect(scenario.viewModel.page.mode == .shaped && scenario.viewModel.page.text == text)
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.text == text)
    }

    // MARK: - Saving as it goes

    @Test func writingIsSavedWithoutADoneButton() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.title = "Renamed"
        scenario.viewModel.page.text = "New words."
        scenario.viewModel.commitPage()
        let saved = scenario.library.script(id: scenario.viewModel.scriptID)
        #expect(saved?.title == "Renamed" && saved?.text == "New words.")
        #expect(saved?.version == 1)
    }

    @Test func changingTheWordsOfAScriptWithTakesMakesOneNewVersionPerVisit() {
        let scenario = makeScenario(takeCount: 2)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.text = "First change."
        scenario.viewModel.commitPage()
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.version == 2)
        #expect(scenario.toast.message == "Saved as v2 · 2 takes on v1")
        scenario.viewModel.page.text = "Second change."
        scenario.viewModel.commitPage()
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.version == 2)
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.text == "Second change.")
    }

    @Test func onlyAnotherSpacingBetweenParagraphsIsNotAChange() {
        let scenario = makeScenario(script: TestData.script(text: "One.\n\nTwo."), takeCount: 1)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.text = "One.\nTwo."
        scenario.viewModel.commitPage()
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.version == 1)
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.text == "One.\n\nTwo.")
    }

    @Test func renamingKeepsTheVersionAndRenamesTheTakes() {
        let scenario = makeScenario(takeCount: 1)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.title = "A new name"
        scenario.viewModel.commitPage()
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.version == 1)
        #expect(scenario.viewModel.scriptTakes.first?.scriptTitle == "A new name")
    }

    @Test func aToolThatChangesTheWordsUpdatesThePage() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.viewModel.page.text == "Rewritten with energy!")
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.text == "Rewritten with energy!")
    }

    @Test func theFullEditorStartsFromWhatIsOnThePageAndComesBackWithItsChanges() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.text = "Typed on the page."
        scenario.viewModel.startEditing()
        #expect(scenario.viewModel.draftText == "Typed on the page.")
        scenario.viewModel.draftText = "Typed in the editor."
        scenario.viewModel.finishEditing()
        #expect(scenario.viewModel.page.text == "Typed in the editor.")
        // Discarding brings the page back to what the script held.
        scenario.viewModel.startEditing()
        scenario.viewModel.draftText = "Thrown away."
        scenario.viewModel.cancelEditing()
        #expect(scenario.viewModel.page.text == "Typed in the editor.")
    }

    // MARK: - Shaped

    @Test func theTipsAreDismissedForGood() {
        let scenario = makeScenario(script: TestData.script(text: "Okay " + TestData.words(30) + ".\n\nBody.\n\nFollow me."))
        defer { scenario.defaults.tearDown() }
        let tip = scenario.viewModel.visibleTip(scenario.viewModel.shaped.hookTip)
        #expect(tip != nil)
        scenario.viewModel.dismiss(tip!)
        #expect(scenario.viewModel.visibleTip(scenario.viewModel.shaped.hookTip) == nil)
    }

    @Test func fixingTheHookAndSuggestingACTAChangeTheWordsAndSaveThem() {
        let scenario = makeScenario(script: TestData.script(text: "One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen, seventeen.\n\nBody."))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.apply(.longHook(seconds: 6))
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.text.hasPrefix("One two three four five six seven eight.") == true)
        scenario.viewModel.suggestCTA()
        #expect(scenario.viewModel.page.text.hasSuffix(ScriptShape.suggestedCTA))
    }

    @Test func recordingAPastTheIdealRangeScriptFromTheDraftAsksOnce() {
        let long = TestData.script(text: TestData.words(400))
        let scenario = makeScenario(script: long)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setMode(.draft)
        #expect(scenario.viewModel.isLongForPlatform)
        #expect(!scenario.viewModel.recordsNow())
        #expect(scenario.viewModel.page.showsLengthNudge)
        // Asked once: the second Rec goes through.
        scenario.viewModel.page.showsLengthNudge = false
        #expect(scenario.viewModel.recordsNow())
    }

    @Test func recordingFromShapedOrAShortScriptNeverAsks() {
        let long = makeScenario(script: TestData.script(text: TestData.words(400)))
        defer { long.defaults.tearDown() }
        #expect(long.viewModel.recordsNow())
        let short = makeScenario()
        defer { short.defaults.tearDown() }
        short.viewModel.setMode(.draft)
        #expect(!short.viewModel.isLongForPlatform && short.viewModel.recordsNow())
    }

    // MARK: - Draft helpers

    @Test func aCueBreakIsAPauseMarkAtTheEndWhenThereIsNoCaret() {
        let scenario = makeScenario(script: TestData.script(text: "Hello there"))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setMode(.draft)
        scenario.viewModel.insertCueBreak()
        #expect(scenario.viewModel.page.text == "Hello there [pause] ")
    }

    @Test func theTextSizeCyclesThroughTheThree() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let first = scenario.viewModel.page.textSize
        scenario.viewModel.cycleTextSize()
        scenario.viewModel.cycleTextSize()
        scenario.viewModel.cycleTextSize()
        #expect(scenario.viewModel.page.textSize == first)
    }

    @Test func aSelectionNeedsMoreThanEightCharactersToOfferRewrites() {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend"))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setMode(.draft)
        let text = scenario.viewModel.page.text
        scenario.viewModel.page.selection = TextSelection(range: text.startIndex..<text.index(text.startIndex, offsetBy: 5))
        #expect(scenario.viewModel.selectedText == nil)
        scenario.viewModel.page.selection = TextSelection(range: text.startIndex..<text.endIndex)
        #expect(scenario.viewModel.selectedText == "Hello there my friend")
    }

    @Test func aRewriteWaitsForUseAndKeepMineLeavesTheWordsAlone() async {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend"))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setMode(.draft)
        let text = scenario.viewModel.page.text
        scenario.viewModel.page.selection = TextSelection(range: text.startIndex..<text.endIndex)
        await scenario.viewModel.rewriteSelection(.shorter)
        #expect(scenario.writer.lastRewrite?.tool == .shorterAndDirect)
        #expect(scenario.viewModel.page.candidate?.rewritten == "Rewritten with energy!")
        #expect(scenario.viewModel.page.text == "Hello there my friend")
        scenario.viewModel.keepMine()
        #expect(scenario.viewModel.page.candidate == nil && scenario.viewModel.page.text == "Hello there my friend")

        scenario.viewModel.page.selection = TextSelection(range: text.startIndex..<text.endIndex)
        await scenario.viewModel.rewriteSelection(.inMyVoice)
        scenario.viewModel.useCandidate()
        #expect(scenario.viewModel.page.text == "Rewritten with energy!")
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.text == "Rewritten with energy!")
    }

    @Test func withoutAModelARewriteSaysWhy() async {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend"))
        defer { scenario.defaults.tearDown() }
        scenario.writer.isAvailable = false
        scenario.viewModel.setMode(.draft)
        let text = scenario.viewModel.page.text
        scenario.viewModel.page.selection = TextSelection(range: text.startIndex..<text.endIndex)
        await scenario.viewModel.rewriteSelection(.rewrite)
        #expect(scenario.viewModel.page.candidate == nil && scenario.toast.message != nil)
    }

    // MARK: - The AI writes into the page

    @Test func theIdeaIsWrittenIntoTheEmptyPageAndTheCardEmpties() async {
        let scenario = makeScenario(script: TestData.script(title: "", text: ""), writing: request())
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.writer.generatedTitle = "Carnival"
        scenario.viewModel.beginWritingIfNeeded()
        #expect(scenario.viewModel.page.isWriting)
        await scenario.viewModel.pageWritingTask?.value
        #expect(!scenario.viewModel.page.isWriting && scenario.viewModel.page.revealed == nil)
        #expect(scenario.viewModel.page.mode == .draft)
        let saved = scenario.library.script(id: scenario.viewModel.scriptID)
        #expect(saved?.title == "Carnival" && saved?.text == scenario.writer.generatedText)
        #expect(scenario.ideaDraft.isEmpty)
        #expect(scenario.toast.message == "Draft ready · Edit anything")
    }

    @Test func aFactualIdeaAsksForACheck() async {
        let factual = ScriptRequest(
            source: .prompt("2 minutes on how the electric shower was invented in Brazil"), platform: .tiktok, tone: nil, voice: nil,
            targetRange: 60...90
        )
        let scenario = makeScenario(script: TestData.script(title: "", text: ""), writing: factual)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.beginWritingIfNeeded()
        await scenario.viewModel.pageWritingTask?.value
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.factCheck == true)
        #expect(scenario.viewModel.needsFactCheck)
    }

    @Test func aFailureKeepsTheIdeaAndCanBeTriedAgain() async {
        let scenario = makeScenario(script: TestData.script(title: "", text: ""), writing: request())
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.writer.error = ScriptAIError.emptyResponse
        scenario.viewModel.beginWritingIfNeeded()
        await scenario.viewModel.pageWritingTask?.value
        #expect(!scenario.viewModel.page.isWriting && scenario.viewModel.page.writingError != nil)
        #expect(scenario.ideaDraft.text == "Carnival in Salvador")
        scenario.writer.error = nil
        scenario.viewModel.retryWriting()
        await scenario.viewModel.pageWritingTask?.value
        #expect(scenario.viewModel.page.writingError == nil)
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.text == scenario.writer.generatedText)
    }

    @Test func stopKeepsOnlyTheWordsThatArrivedAndEndsTheWriting() {
        let scenario = makeScenario(script: TestData.script(title: "", text: ""), writing: request())
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.beginWritingIfNeeded()
        // Nothing has arrived yet: stopping leaves an empty page, a writer that's done, and no error.
        scenario.viewModel.stopWriting()
        #expect(!scenario.viewModel.page.isWriting && scenario.viewModel.page.text.isEmpty)
        #expect(scenario.viewModel.page.writingError == nil)
    }

    @Test func stoppingBeforeTheFirstWordKeepsTheIdeaOnTheCard() {
        let scenario = makeScenario(script: TestData.script(title: "", text: ""), writing: request())
        defer { scenario.defaults.tearDown() }
        scenario.ideaDraft.text = "Carnival in Salvador"
        scenario.viewModel.beginWritingIfNeeded()
        scenario.viewModel.stopWriting()
        #expect(scenario.ideaDraft.text == "Carnival in Salvador")
    }

    @Test func anErrorIsNotRetriedJustBecauseThePageShowsAgain() async {
        let scenario = makeScenario(script: TestData.script(title: "", text: ""), writing: request())
        defer { scenario.defaults.tearDown() }
        scenario.writer.error = ScriptAIError.emptyResponse
        scenario.viewModel.beginWritingIfNeeded()
        await scenario.viewModel.pageWritingTask?.value
        #expect(scenario.viewModel.page.writingError != nil)
        scenario.writer.error = nil
        scenario.viewModel.beginWritingIfNeeded()
        #expect(!scenario.viewModel.page.isWriting, "only Try again starts it once more")
        #expect(scenario.viewModel.page.writingError != nil)
    }

    @Test func askedTwiceItWritesOnlyOnce() async {
        let scenario = makeScenario(script: TestData.script(title: "", text: ""), writing: request())
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.beginWritingIfNeeded()
        scenario.viewModel.beginWritingIfNeeded()
        await scenario.viewModel.pageWritingTask?.value
        #expect(scenario.library.scripts.count == 1)
    }

    // MARK: - The voice preview

    private func voice(_ scenario: Scenario) -> CreatorVoice {
        scenario.profile.saveVoiceSetup(niches: [.tech], vocabulary: .simple, sounds: [.casual])
        return scenario.profile.profile.voice
    }

    @Test func aScriptWrittenInTheVoiceIsItsOwnPreviewUntilApproved() async {
        let scenario = makeScenario(script: TestData.script(title: "", text: ""))
        defer { scenario.defaults.tearDown() }
        let withVoice = request(voice: voice(scenario))
        scenario.viewModel.write(withVoice)
        await scenario.viewModel.pageWritingTask?.value
        #expect(scenario.viewModel.showsVoicePreview)
        // "Without" writes the same idea with no voice, once.
        scenario.writer.generatedText = "Neutral words."
        scenario.viewModel.showVoice(.without)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(scenario.writer.lastRequest?.voice == nil)
        #expect(scenario.viewModel.previewedText == "Neutral words.")
        #expect(scenario.viewModel.page.text != "Neutral words.")
        scenario.viewModel.showVoice(.mine)
        #expect(scenario.viewModel.previewedText == nil)
        scenario.viewModel.approveVoice()
        #expect(!scenario.viewModel.showsVoicePreview && scenario.profile.profile.voiceApproved)
    }

    @Test func aScriptWrittenWithoutTheVoiceHasNoPreview() async {
        let scenario = makeScenario(script: TestData.script(title: "", text: ""))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.write(request())
        await scenario.viewModel.pageWritingTask?.value
        #expect(!scenario.viewModel.showsVoicePreview)
    }

    @Test func adjustingForThisScriptOnlyLeavesTheProfileAlone() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        _ = voice(scenario)
        scenario.profile.profile.phrases = ["Hey fam"]
        await scenario.viewModel.rewriteVoice(adjustments: [.notMyPhrase], keepsInProfile: false)
        #expect(scenario.writer.lastRewrite?.context.voice?.phrases == [])
        #expect(scenario.profile.profile.phrases == ["Hey fam"])
        await scenario.viewModel.rewriteVoice(adjustments: [.notMyPhrase], keepsInProfile: true)
        #expect(scenario.profile.profile.phrases.isEmpty)
    }
}
