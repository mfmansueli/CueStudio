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

    private func makeScenario(script: Script, takeCount: Int = 0) -> Scenario {
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
        return Scenario(viewModel: viewModel, library: library, writer: writer, toast: toast, defaults: defaults)
    }

    @Test func replacingTheHookSavesRightAway() {
        let script = TestData.script(text: "Old hook.\n\nBody.")
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.replaceHook(with: "New hook.")
        #expect(scenario.library.script(id: script.id)?.text == "New hook.\n\nBody.")
        #expect(scenario.viewModel.sheet == nil)
    }

    @Test func disclosureIsSavedAndCanBeUndone() async {
        let script = TestData.script(text: "Buy this.", type: .ad)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.addDisclosure)
        #expect(scenario.library.script(id: script.id)?.text.hasPrefix("[paid partnership] ") == true)
        #expect(scenario.viewModel.page.text.hasPrefix("[paid partnership] "))
        scenario.toast.action?.perform()
        #expect(scenario.library.script(id: script.id)?.text == "Buy this.")
        #expect(scenario.viewModel.page.text == "Buy this.")
    }

    @Test func rewriteWithoutTheModelExplainsWhy() async {
        let script = TestData.script(text: "Calm words.")
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.writer.isAvailable = false
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.library.script(id: script.id)?.text == "Calm words.")
        #expect(scenario.toast.message == "Requires Apple Intelligence.")
    }

    @Test func inMyVoiceComesFirstAndRewritesWithTheVoice() async {
        let script = TestData.script(text: "Plain words.", type: .apology)
        let scenario = makeScenario(script: script)
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
        let scenario = makeScenario(script: script)
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
        let scenario = makeScenario(script: TestData.script(title: "Habits"))
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.translate)
        #expect(scenario.writer.lastRewrite == nil)
        #expect(scenario.library.scripts.count == 1)
    }

    @Test func theRewriteKnowsTheLanguageTheScriptIsWrittenIn() async {
        let portuguese = TestData.script(text: "Esses são três hábitos que mudaram as minhas manhãs. Primeiro, eu bebo um copo de água.")
        let scenario = makeScenario(script: portuguese)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.writer.lastRewrite?.context.sourceLanguage?.languageCode?.identifier == "pt")
        // The script's own language, when it has one, is what counts.
        scenario.library.setLanguage(.thai, of: portuguese.id)
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.writer.lastRewrite?.context.sourceLanguage?.languageCode?.identifier == "th")
    }

    @Test func stoppingAnAIToolIsNotAnErrorToShow() async {
        let scenario = makeScenario(script: TestData.script())
        defer { scenario.defaults.tearDown() }
        scenario.writer.error = CancellationError()
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.toast.message == nil)
        #expect(scenario.viewModel.runningTool == nil)
    }

    @Test func aLanguageProblemIsToldAsTheCreatorCanActOnIt() async {
        let scenario = makeScenario(script: TestData.script())
        defer { scenario.defaults.tearDown() }
        scenario.writer.error = ScriptAIError.unsupportedTranslation(source: "Portuguese", target: "Thai")
        await scenario.viewModel.run(.translate, language: .thai)
        #expect(scenario.toast.message?.contains("Thai") == true)
        #expect(scenario.library.scripts.count == 1)
    }

    // MARK: - Everything is free

    @Test func inMyVoiceUsesTheWholeVoice() async {
        let scenario = makeScenario(script: TestData.script())
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
        // It is saved, and says how far it is from the length when it is not there ("Short and punchy." is three words).
        #expect(scenario.toast.message?.hasPrefix("Reels version saved · Closer to ") == true)
    }

    @Test func aVersionThatIsTheRightLengthIsJustSaved() async {
        let script = TestData.script(title: "Habits", platform: .tiktok)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        let range = TestData.rules.preset(for: .reels, monetizationGoals: true).idealRange
        scenario.writer.rewrittenText = (0..<ReadTime.words(for: (range.lowerBound + range.upperBound) / 2)).map { "w\($0)" }.joined(separator: " ")
        await scenario.viewModel.makeVersion(for: .reels)
        #expect(scenario.toast.message == "Reels version saved")
    }

    @Test func aToolHasNothingToWorkOnInAnEmptyScript() async {
        let script = TestData.script(title: "Blank", text: "", platform: .tiktok)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.moreEnergy)
        #expect(scenario.writer.lastRewrite == nil)
        #expect(scenario.toast.message == "Write something first, then Cue can improve it")
    }

    @Test func destinationChangeAppliesThePreset() {
        let script = TestData.script(platform: .tiktok)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setPlatform(.youtube)
        #expect(scenario.library.script(id: script.id)?.platform == .youtube)
        #expect(scenario.viewModel.preset.prefersStudio)
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
}
