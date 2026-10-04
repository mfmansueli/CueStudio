//
//  ScriptPageViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import SwiftUI
import Testing
@testable import Cue_Studio

/// The script page (v29): one page of words saved as the creator writes, its state, Done, the AI bar on a selection and the AI
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

    @Test func aBlankScriptTakesTheTitleAndADraftOpenedWithContinueTakesTheText() {
        let blank = makeScenario(script: TestData.script(title: "", text: ""))
        defer { blank.defaults.tearDown() }
        #expect(blank.viewModel.page.isLoaded && blank.viewModel.page.focusesTitle && !blank.viewModel.page.focusesText)
        let continuing = makeScenario(startsEditing: true)
        defer { continuing.defaults.tearDown() }
        #expect(continuing.viewModel.page.focusesText && !continuing.viewModel.page.focusesTitle)
        let reading = makeScenario()
        defer { reading.defaults.tearDown() }
        #expect(!reading.viewModel.page.focusesText && !reading.viewModel.page.focusesTitle)
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

    @Test func recordingAPastTheIdealRangeScriptAsksOnce() {
        let long = TestData.script(text: TestData.words(400))
        let scenario = makeScenario(script: long)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.isLongForPlatform)
        #expect(!scenario.viewModel.recordsNow())
        #expect(scenario.viewModel.page.showsLengthNudge)
        // Asked once: the second Record goes through.
        scenario.viewModel.page.showsLengthNudge = false
        #expect(scenario.viewModel.recordsNow())
    }

    @Test func recordingAShortOrAlreadyRecordedScriptNeverAsks() {
        let short = makeScenario()
        defer { short.defaults.tearDown() }
        #expect(!short.viewModel.isLongForPlatform && short.viewModel.recordsNow())
        let recorded = makeScenario(script: TestData.script(text: TestData.words(400)), takeCount: 1)
        defer { recorded.defaults.tearDown() }
        #expect(recorded.viewModel.recordsNow())
    }

    // MARK: - Cues

    @Test func aCueFromTheBarGoesAtTheEndWhenThereIsNoCaret() {
        let scenario = makeScenario(script: TestData.script(text: "Hello there"))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.insertCue(.pause)
        #expect(scenario.viewModel.page.text == "Hello there [pause] ")
    }

    @Test func aCueGoesWhereTheCaretIsAndTheCaretMovesAfterIt() {
        let scenario = makeScenario(script: TestData.script(text: "Hello world"))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.selection = 5..<5
        scenario.viewModel.insertCue(.smile)
        #expect(scenario.viewModel.page.text == "Hello [smile]  world")
        #expect(scenario.viewModel.page.selection == 14..<14)
    }

    @Test func theBarHasTheFourCuesOfTheBoard() {
        #expect(ScriptCue.bar.map(\.name) == ["pause", "smile", "emphasis", "look at camera"])
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
        scenario.viewModel.page.selection = 0..<5
        #expect(scenario.viewModel.selectedText == nil && !scenario.viewModel.showsSelectionBar)
        scenario.viewModel.page.selection = 0..<21
        #expect(scenario.viewModel.selectedText == "Hello there my friend")
        #expect(scenario.viewModel.showsSelectionBar)
    }

    @Test func withoutAppleIntelligenceThereIsNoBar() {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend"))
        defer { scenario.defaults.tearDown() }
        scenario.writer.isAvailable = false
        scenario.viewModel.page.selection = 0..<21
        #expect(!scenario.viewModel.showsSelectionBar)
    }

    @Test func aRewriteReplacesTheWordsInPlaceAndWaitsForKeep() async {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend. More words follow."))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.selection = 0..<21
        await scenario.viewModel.rewriteSelection(.shorter)
        #expect(scenario.writer.lastRewrite?.tool == .shorterAndDirect)
        #expect(scenario.viewModel.page.text == "Rewritten with energy!. More words follow.")
        #expect(scenario.viewModel.page.passage?.original == "Hello there my friend")
        #expect(scenario.viewModel.page.passage?.range == 0..<22)
        let beforeKeep = scenario.library.script(id: scenario.viewModel.scriptID)?.text
        #expect(beforeKeep == "Hello there my friend. More words follow.", "not saved until kept or edited on")
        scenario.viewModel.keepPassage()
        #expect(scenario.viewModel.page.passage == nil)
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.text == "Rewritten with energy!. More words follow.")
    }

    @Test func undoPutsTheOldWordsBack() async {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend. More words follow."))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.selection = 0..<21
        await scenario.viewModel.rewriteSelection(.rewrite)
        scenario.viewModel.undoPassage()
        #expect(scenario.viewModel.page.text == "Hello there my friend. More words follow.")
        #expect(scenario.viewModel.page.passage == nil)
    }

    @Test func tryAgainAsksTheSameChangeOfTheSameWords() async {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend. More words follow."))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.selection = 0..<21
        await scenario.viewModel.rewriteSelection(.punchier)
        scenario.writer.rewrittenText = "Hi!"
        await scenario.viewModel.retryPassage()
        #expect(scenario.writer.lastRewrite?.tool == .moreEnergy)
        #expect(scenario.viewModel.page.text == "Hi!. More words follow.")
        #expect(scenario.viewModel.page.passage?.original == "Hello there my friend")
    }

    @Test func moreMeUsesTheCreatorsVoice() async {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend"))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.selection = 0..<21
        await scenario.viewModel.rewriteSelection(.moreMe)
        #expect(scenario.writer.lastRewrite?.tool == .inMyVoice)
    }

    @Test func cutRemovesTheWordsWithoutTheAIAndCanBeUndone() async throws {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend. More words follow."))
        defer { scenario.defaults.tearDown() }
        scenario.writer.isAvailable = false
        scenario.viewModel.page.selection = 0..<22
        await scenario.viewModel.rewriteSelection(.cut)
        #expect(scenario.viewModel.page.text == " More words follow.")
        #expect(scenario.writer.lastRewrite == nil)
        try #require(scenario.toast.action).perform()
        #expect(scenario.viewModel.page.text == "Hello there my friend. More words follow.")
    }

    @Test func aFailedRewriteSaysSoAndKeepsTheWords() async {
        let scenario = makeScenario(script: TestData.script(text: "Hello there my friend"))
        defer { scenario.defaults.tearDown() }
        scenario.writer.error = ScriptAIError.emptyResponse
        scenario.viewModel.page.selection = 0..<21
        await scenario.viewModel.rewriteSelection(.rewrite)
        #expect(scenario.viewModel.page.passage == nil && scenario.viewModel.page.text == "Hello there my friend")
        #expect(scenario.toast.message == "Couldn’t write it · Try again")
    }

    // MARK: - State (04 · F2)

    @Test func doneMakesADraftReadyAndKeepsTheWords() {
        let scenario = makeScenario(script: TestData.script(text: "One.\n\nTwo.", isFinished: false))
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.strip?.state == .draft)
        scenario.viewModel.done()
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.isFinished == true)
        #expect(scenario.viewModel.strip?.state == .ready)
        #expect(scenario.toast.message?.hasPrefix("Ready to record") == true)
    }

    @Test func doneWithNoTextSavesNothing() {
        let scenario = makeScenario(script: TestData.script(title: "", text: ""))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.done()
        #expect(scenario.toast.message == "Nothing to save yet")
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.isFinished == false)
    }

    @Test func doneWithEmptySectionsAsksFirstAndDoneAnywayFinishes() {
        let scenario = makeScenario(script: TestData.script(text: "Only a hook.", type: .tutorial, isFinished: false))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.done()
        #expect(scenario.viewModel.page.emptySectionsToConfirm == 3)
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.isFinished == false)
        scenario.viewModel.finish()
        #expect(scenario.viewModel.page.emptySectionsToConfirm == nil)
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.isFinished == true)
    }

    @Test func editingAReadyScriptAndLeavingWithoutDoneMakesItADraft() {
        let scenario = makeScenario(script: TestData.script(text: "One.\n\nTwo."))
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.strip?.state == .ready)
        scenario.viewModel.page.text = "One.\n\nTwo and more."
        scenario.viewModel.pageDidEdit()
        #expect(scenario.viewModel.strip?.isEdited == true)
        scenario.viewModel.leavePage()
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.isFinished == false)
        #expect(scenario.toast.message == "Saved as draft")
    }

    @Test func editingThenDoneThenLeavingStaysReady() {
        let scenario = makeScenario(script: TestData.script(text: "One.\n\nTwo."))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.text = "One.\n\nTwo and more."
        scenario.viewModel.pageDidEdit()
        scenario.viewModel.done()
        scenario.viewModel.leavePage()
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.isFinished == true)
        #expect(scenario.toast.message?.hasPrefix("Ready to record") == true)
    }

    @Test func editingAfterRecordingStaysRecordedAndTheStripSaysChanged() {
        let scenario = makeScenario(script: TestData.script(text: "One.\n\nTwo."), takeCount: 2)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.page.text = "One.\n\nTwo, changed."
        scenario.viewModel.pageDidEdit()
        scenario.viewModel.commitPage()
        scenario.viewModel.leavePage()
        let strip = scenario.viewModel.strip
        #expect(strip?.state == .recorded)
        #expect(strip?.changedSinceTake == 2)
        #expect(strip?.info == ["Changed since take 2"])
        #expect(scenario.toast.message != "Saved as draft")
    }

    @Test func recordingADraftSendsItToTheCameraAsReady() {
        let scenario = makeScenario(script: TestData.script(text: "One.\n\nTwo.", isFinished: false))
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.recordsNow())
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.isFinished == true)
    }

    @Test func shapeAddsCuesAndNeverChangesTheState() {
        let scenario = makeScenario(script: TestData.script(text: "First hook line. More hook.\n\nThe point is here. Another.\n\nTry it out. Follow me.", isFinished: false))
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.shape()
        #expect(CueParser.count(in: scenario.viewModel.page.text) == 4)
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.isFinished == false)
        #expect(scenario.toast.message == "4 cues added")
        #expect(scenario.viewModel.strip?.canShape == false)
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
        #expect(scenario.library.script(id: scenario.viewModel.scriptID)?.isFinished == true, "the AI delivered a complete script: READY")
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
