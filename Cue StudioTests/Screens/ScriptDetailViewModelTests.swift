//
//  ScriptDetailViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("ScriptDetailViewModel")
struct ScriptDetailViewModelTests {
    private struct Scenario {
        let viewModel: ScriptDetailViewModel
        let library: ScriptLibraryService
        let writer: FakeScriptWriter
        let toast: ToastService
        let defaults: TestDefaults
    }

    private func makeScenario(script: Script, takeCount: Int = 0, startsEditing: Bool = false) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: (0..<takeCount).map {
            TestData.take(scriptID: script.id, number: $0 + 1)
        }))
        takes.load()
        let writer = FakeScriptWriter()
        let toast = ToastService()
        // A creator who has answered the voice: what "In my voice" sends is what they answered.
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.saveVoiceSetup(niches: [.tech], vocabulary: .simple, sounds: [.casual, .confident])
        let viewModel = ScriptDetailViewModel(
            scriptID: script.id,
            library: library,
            takes: takes,
            preferences: PreferencesService(defaults: defaults.defaults),
            profile: profile,
            rules: TestData.rulesService(),
            writer: writer,
            toast: toast
        )
        // The writing editor ("Versions & options") is what these tests drive.
        if startsEditing { viewModel.startEditing() }
        return Scenario(viewModel: viewModel, library: library, writer: writer, toast: toast, defaults: defaults)
    }

    @Test func editingTextOfAScriptWithTakesCreatesANewVersion() {
        let script = TestData.script(version: 1)
        let scenario = makeScenario(script: script, takeCount: 3)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.startEditing()
        scenario.viewModel.draftText = "New words."
        scenario.viewModel.finishEditing()
        #expect(scenario.library.script(id: script.id)?.version == 2)
        #expect(scenario.library.script(id: script.id)?.text == "New words.")
        #expect(scenario.toast.message == "Saved as v2 · 3 takes on v1")
        #expect(!scenario.viewModel.isEditing)
    }

    @Test func editingWithoutTakesKeepsTheVersion() {
        let script = TestData.script()
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.startEditing()
        scenario.viewModel.draftText = "New words."
        scenario.viewModel.finishEditing()
        #expect(scenario.library.script(id: script.id)?.version == 1)
        #expect(scenario.toast.message == "Saved")
    }

    @Test func renamingAloneKeepsTheVersion() {
        let script = TestData.script()
        let scenario = makeScenario(script: script, takeCount: 1)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.startEditing()
        scenario.viewModel.draftTitle = "Renamed"
        scenario.viewModel.finishEditing()
        #expect(scenario.library.script(id: script.id)?.version == 1)
        #expect(scenario.library.script(id: script.id)?.title == "Renamed")
    }

    @Test func cancelDiscardsTheDraft() {
        let script = TestData.script(text: "Original.")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.draftText = "Changed."
        scenario.viewModel.cancelEditing()
        #expect(scenario.library.script(id: script.id)?.text == "Original.")
        #expect(scenario.viewModel.workingText == "Original.")
    }

    @Test func unchangedDraftSavesNothing() {
        let script = TestData.script()
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.finishEditing()
        #expect(scenario.toast.message == nil)
    }

    @Test func spacingBetweenParagraphsAloneIsNotAChange() {
        // A script saved with single line breaks keeps them, and no version, when nothing was said.
        let script = TestData.script(text: "One.\nTwo.\n\nThree.")
        let scenario = makeScenario(script: script, takeCount: 2, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.finishEditing()
        #expect(scenario.library.script(id: script.id)?.text == "One.\nTwo.\n\nThree.")
        #expect(scenario.library.script(id: script.id)?.version == script.version)
        #expect(scenario.toast.message == nil)
    }

    @Test func replacingTheHookInReadModeSavesRightAway() {
        let script = TestData.script(text: "Old hook.\n\nBody.")
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.replaceHook(with: "New hook.")
        #expect(scenario.library.script(id: script.id)?.text == "New hook.\n\nBody.")
        #expect(scenario.viewModel.sheet == nil)
    }

    @Test func disclosureCanBeUndone() async {
        let script = TestData.script(text: "Buy this.", type: .ad)
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.addDisclosure)
        #expect(scenario.viewModel.draftText.hasPrefix("[paid partnership] "))
        scenario.viewModel.undoRewrite()
        #expect(scenario.viewModel.draftText == "Buy this.")
    }

    @Test func rewriteReplacesTheDraft() async {
        let script = TestData.script(text: "Calm words.")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.viewModel.draftText == "Rewritten with energy!")
        #expect(scenario.viewModel.undoText == "Calm words.")
        #expect(scenario.writer.lastRewrite?.tool == .moreEnergy)
    }

    @Test func rewriteWithoutTheModelExplainsWhy() async {
        let script = TestData.script(text: "Calm words.")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.writer.isAvailable = false
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.viewModel.draftText == "Calm words.")
        #expect(scenario.toast.message == "Requires Apple Intelligence.")
    }

    @Test func inMyVoiceComesFirstAndRewritesWithTheVoice() async {
        let script = TestData.script(text: "Plain words.", type: .apology)
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.tools.first == .inMyVoice)
        #expect(scenario.viewModel.tools.contains(.lessDefensive))
        await scenario.viewModel.run(.inMyVoice)
        #expect(scenario.writer.lastRewrite?.tool == .inMyVoice)
        #expect(scenario.writer.lastRewrite?.context.voice?.sounds == [.casual, .confident])
    }

    @Test func newHooksAreWrittenForThisScript() async {
        let script = TestData.script(text: "Old hook.\n\nBody.")
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.openHooks()
        #expect(scenario.viewModel.sheet == .hooks)
        #expect(scenario.viewModel.hookOptions == ["New hook one.", "New hook two.", "New hook three."])
        await scenario.viewModel.showMoreHooks()
        #expect(scenario.writer.hooksRequested == 2)
    }

    @Test func withoutTheModelHooksComeFromTheFormat() async {
        let script = TestData.script(text: "Old hook.\n\nBody.")
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.writer.isAvailable = false
        await scenario.viewModel.openHooks()
        let first = scenario.viewModel.hookOptions
        #expect(first == ScriptTextEditing.hookOptions(from: ScriptStructure.generic.hooks, rotation: 0))
        await scenario.viewModel.showMoreHooks()
        #expect(scenario.viewModel.hookOptions != first)
    }

    @Test func checkedClearsTheFactCheckWithoutReordering() {
        var script = TestData.script()
        script.factCheck = true
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.needsFactCheck)
        scenario.viewModel.markFactChecked()
        #expect(!scenario.viewModel.needsFactCheck)
        #expect(scenario.library.script(id: script.id)?.updatedAt == TestData.now)
        #expect(scenario.toast.message == "Marked as fact-checked")
    }

    @Test func translationIsSavedAsACopy() async {
        let script = TestData.script(title: "Habits")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.writer.rewrittenText = "Hola."
        await scenario.viewModel.run(.translate, language: .spanish)
        let copy = scenario.library.scripts.first { $0.id != script.id }
        #expect(copy?.title == "Habits (Spanish)")
        #expect(copy?.text == "Hola.")
        #expect(scenario.writer.lastRewrite?.context.language == .spanish)
    }

    /// There is no default language to translate into: without the creator's pick nothing is sent.
    @Test func translatingWithoutATargetDoesNothing() async {
        let scenario = makeScenario(script: TestData.script(title: "Habits"), startsEditing: true)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.translate)
        #expect(scenario.writer.lastRewrite == nil)
        #expect(scenario.library.scripts.count == 1)
    }

    @Test func theRewriteKnowsTheLanguageTheScriptIsWrittenIn() async {
        let portuguese = TestData.script(text: "Esses são três hábitos que mudaram as minhas manhãs. Primeiro, eu bebo um copo de água.")
        let scenario = makeScenario(script: portuguese, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.writer.lastRewrite?.context.sourceLanguage?.languageCode?.identifier == "pt")
        // The script's own language, when it has one, is what counts.
        scenario.library.setLanguage(.thai, of: portuguese.id)
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.writer.lastRewrite?.context.sourceLanguage?.languageCode?.identifier == "th")
    }

    @Test func stoppingAnAIToolIsNotAnErrorToShow() async {
        let scenario = makeScenario(script: TestData.script(), startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.writer.error = CancellationError()
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.toast.message == nil)
        #expect(scenario.viewModel.runningTool == nil)
    }

    @Test func aLanguageProblemIsToldAsTheCreatorCanActOnIt() async {
        let scenario = makeScenario(script: TestData.script(), startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.writer.error = ScriptAIError.unsupportedTranslation(source: "Portuguese", target: "Thai")
        await scenario.viewModel.run(.translate, language: .thai)
        #expect(scenario.toast.message?.contains("Thai") == true)
        #expect(scenario.library.scripts.count == 1)
    }

    // MARK: - Everything is free

    @Test func inMyVoiceUsesTheWholeVoice() async {
        let scenario = makeScenario(script: TestData.script(), startsEditing: true)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.inMyVoice)
        #expect(scenario.writer.lastRewrite?.tool == .inMyVoice)
        #expect(scenario.writer.lastRewrite?.context.voice?.sounds == [.casual, .confident])
    }

    @Test func hooksAreWrittenByTheModel() async {
        let script = TestData.script(text: "Old hook.\n\nBody.")
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.openHooks()
        #expect(scenario.writer.hooksRequested == 1)
        #expect(scenario.viewModel.sheet == .hooks)
    }

    @Test func aVersionForAnotherPlatformIsFittedToItAndSavedAsACopy() async {
        let script = TestData.script(title: "Habits", platform: .tiktok)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        #expect(!scenario.viewModel.versionPlatforms.contains(.tiktok))
        scenario.writer.rewrittenText = "Short and punchy."
        await scenario.viewModel.makeVersion(for: .reels)
        let copy = scenario.library.scripts.first { $0.id != script.id }
        #expect(copy?.title == "Habits (Reels)")
        #expect(copy?.platform == .reels)
        #expect(copy?.text == "Short and punchy.")
        #expect(scenario.writer.lastRewrite?.tool == .fitToTime)
        #expect(scenario.writer.lastRewrite?.context.platform == .reels)
        #expect(scenario.writer.lastRewrite?.context.idealRange == TestData.rules.preset(for: .reels, monetizationGoals: true).idealRange)
        #expect(scenario.library.script(id: script.id)?.text == script.text)
        #expect(scenario.toast.message == "Reels version saved")
    }

    @Test func destinationChangeAppliesThePreset() {
        let script = TestData.script(platform: .tiktok)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setPlatform(.youtube)
        #expect(scenario.library.script(id: script.id)?.platform == .youtube)
        #expect(scenario.viewModel.preset.prefersStudio)
    }

    // MARK: - Writing

    @Test func editingStartsWithTheCaretAtTheEndOfTheParagraphTapped() {
        let script = TestData.script(text: "First line.\n\nSecond line.")
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.startEditing(atParagraph: 1)
        #expect(scenario.viewModel.draftParagraphs == ["First line.", "Second line."])
        #expect(scenario.viewModel.focus?.index == 1)
        #expect(scenario.viewModel.focus?.offset == "Second line.".utf16.count)
    }

    @Test func returnSplitsTheParagraphAndBackspaceJoinsItAgain() {
        let script = TestData.script(text: "Hello world.")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        // Return after "Hello": the new text has the break in it, the caret just after it.
        viewModel.replaceParagraph(0, with: "Hello\n world.", caret: 6)
        #expect(viewModel.draftParagraphs == ["Hello", " world."])
        #expect(viewModel.focus?.index == 1 && viewModel.focus?.offset == 0)
        viewModel.mergeWithPrevious(1)
        #expect(viewModel.draftParagraphs == ["Hello  world."])
        #expect(viewModel.focus?.index == 0 && viewModel.focus?.offset == 6)
    }

    @Test func emptyParagraphsAreNotSaved() {
        let script = TestData.script(text: "Words.")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.replaceParagraph(0, with: "Words.\n", caret: 7)
        #expect(scenario.viewModel.draftParagraphs == ["Words.", ""])
        #expect(scenario.viewModel.draftText == "Words.")
        scenario.viewModel.setParagraph(1, to: "More.")
        scenario.viewModel.finishEditing()
        #expect(scenario.library.script(id: script.id)?.text == "Words.\n\nMore.")
    }

    @Test func aCueGoesAtTheCaretAndThePanelStaysOpen() {
        let script = TestData.script(text: "Okay, real talk.")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        viewModel.noteCaret(paragraph: 0, offset: 6)
        viewModel.toggle(.cues)
        viewModel.insertEditorCue(.pause)
        #expect(viewModel.draftParagraphs == ["Okay, [pause] real talk."])
        #expect(viewModel.tool == .cues)
        #expect(viewModel.caret == ScriptParagraphs.Caret(index: 0, offset: 6 + "[pause] ".utf16.count))
    }

    @Test func panelsTakeTheKeyboardsPlaceAndGiveItBack() {
        let scenario = makeScenario(script: TestData.script(), startsEditing: true)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        viewModel.noteFocus(paragraph: 0)
        #expect(viewModel.isInputVisible)
        viewModel.toggle(.ai)
        #expect(viewModel.tool == .ai)
        #expect(viewModel.focus?.index == nil)
        // Another tool swaps; the same one again closes and the caret is asked for.
        viewModel.toggle(.sections)
        #expect(viewModel.tool == .sections)
        viewModel.toggle(.sections)
        #expect(viewModel.tool == nil)
        #expect(viewModel.focus?.index == viewModel.caret.index)
        // The keyboard button puts everything away, then brings the keyboard back.
        viewModel.toggle(.options)
        viewModel.toggleKeyboard()
        #expect(viewModel.tool == nil && viewModel.focus?.index == nil)
        viewModel.noteBlur(paragraph: 0)
        #expect(!viewModel.isInputVisible)
        viewModel.toggleKeyboard()
        #expect(viewModel.focus?.index == viewModel.caret.index)
        // A paragraph taking focus puts a panel away.
        viewModel.toggle(.cues)
        viewModel.noteFocus(paragraph: 0)
        #expect(viewModel.tool == nil)
    }

    @Test func aNewSectionSplitsAtTheCaret() {
        let script = TestData.script(text: "One two.")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.noteCaret(paragraph: 0, offset: 3)
        scenario.viewModel.toggle(.sections)
        scenario.viewModel.addSectionAtCaret()
        #expect(scenario.viewModel.draftParagraphs == ["One", "two."])
        #expect(scenario.viewModel.tool == nil)
        #expect(scenario.viewModel.focus?.index == 1)
    }

    @Test func sectionsFollowTheBlocksIncludingTheEmptyParagraph() {
        let script = TestData.script(text: "Hook.\n\nBody one.\n\nBody two.\n\nClose.", type: .list)
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        let viewModel = scenario.viewModel
        #expect(viewModel.editorSummaries.map(\.firstParagraph) == [0, 1, 3])
        viewModel.noteCaret(paragraph: 2, offset: 0)
        #expect(viewModel.activeSummary?.firstParagraph == 1)
        viewModel.goToSection(viewModel.editorSummaries[2])
        #expect(viewModel.focus?.index == 3)
    }

    @Test func discardChangesBringsTheScriptBackAndSaysSo() {
        let script = TestData.script(text: "Original.")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setParagraph(0, to: "Changed.")
        scenario.viewModel.discardChanges()
        #expect(!scenario.viewModel.isEditing)
        #expect(scenario.library.script(id: script.id)?.text == "Original.")
        #expect(scenario.toast.message == "Changes discarded")
    }

    @Test func anAIToolOffersUndoAndClosesThePanel() async {
        let script = TestData.script(text: "Calm words.")
        let scenario = makeScenario(script: script, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.toggle(.ai)
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.viewModel.tool == nil)
        #expect(scenario.toast.action?.title == "Undo")
        scenario.toast.action?.perform()
        #expect(scenario.viewModel.draftText == "Calm words.")
        #expect(scenario.toast.message == "Undone")
    }

    @Test func anAIToolWhileReadingSavesTheTextAndUndoPutsItBack() async {
        let script = TestData.script(text: "Calm words.", version: 1)
        let scenario = makeScenario(script: script, takeCount: 2)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.library.script(id: script.id)?.text == "Rewritten with energy!")
        // Takes were made from the old words: the new ones are a new version.
        #expect(scenario.library.script(id: script.id)?.version == 2)
        scenario.toast.action?.perform()
        #expect(scenario.library.script(id: script.id)?.text == "Calm words.")
        #expect(scenario.library.script(id: script.id)?.version == 1)
    }

    @Test func theTypeCanBeChangedAndGoesBackToGeneral() {
        let script = TestData.script(type: .list)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setType(.review)
        #expect(scenario.library.script(id: script.id)?.type == .review)
        scenario.viewModel.setType(nil)
        #expect(scenario.library.script(id: script.id)?.type == nil)
        #expect(scenario.viewModel.structure == ScriptStructure.generic)
    }

    @Test func aBlockPickedInTheDetailsScrollsTheReader() {
        let script = TestData.script(text: "Hook.\n\nBody.\n\nClose.")
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.sheet = .details
        scenario.viewModel.showBlock(scenario.viewModel.summaries[1])
        #expect(scenario.viewModel.sheet == nil)
        #expect(scenario.viewModel.readScrollTarget == 1)
    }

    @Test func cuesWhileRecordingFollowTheTeleprompterSetting() {
        let scenario = makeScenario(script: TestData.script())
        defer { scenario.defaults.tearDown() }
        #expect(!scenario.viewModel.showsCues)
        scenario.viewModel.showsCues = true
        #expect(scenario.viewModel.showsCues)
    }
}
