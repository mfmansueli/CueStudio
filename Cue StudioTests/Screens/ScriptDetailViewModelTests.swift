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

    /// Pro by default, so the AI tools run; the free plan has its own tests.
    private func makeScenario(script: Script, takeCount: Int = 0, startsEditing: Bool = false, tier: MembershipTier = .subscriber) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: (0..<takeCount).map {
            TestData.take(scriptID: script.id, number: $0 + 1)
        }))
        takes.load()
        let writer = FakeScriptWriter()
        let toast = ToastService()
        let viewModel = ScriptDetailViewModel(
            scriptID: script.id,
            startsEditing: startsEditing,
            library: library,
            takes: takes,
            preferences: PreferencesService(defaults: defaults.defaults),
            profile: CreatorProfileService(defaults: defaults.defaults),
            rules: TestData.rulesService(),
            writer: writer,
            tier: { tier },
            toast: toast
        )
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
        #expect(scenario.toast.message == "Saved as v2 — 3 takes stay with v1")
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

    @Test func versionNoticeWhileEditingAScriptWithTakes() {
        let script = TestData.script(version: 2)
        let scenario = makeScenario(script: script, takeCount: 2, startsEditing: true)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.versionNotice == "Editing creates v3 · your 2 takes stay linked to v2")
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
        #expect(scenario.viewModel.draftText.hasPrefix(ScriptTextEditing.disclosureLine))
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
        #expect(scenario.writer.lastRewrite?.context.language == "Spanish")
    }

    // MARK: - Pro

    @Test func inMyVoiceIsProOnTheFreePlan() async {
        let scenario = makeScenario(script: TestData.script(), startsEditing: true, tier: .free)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.isLocked(.inMyVoice))
        #expect(!scenario.viewModel.isLocked(.moreEnergy))
        await scenario.viewModel.run(.inMyVoice)
        #expect(scenario.viewModel.paywall == .creatorVoice)
        #expect(scenario.writer.lastRewrite == nil)
    }

    @Test func freeRewritesUseTheFreePartOfTheVoice() async {
        let scenario = makeScenario(script: TestData.script(), startsEditing: true, tier: .free)
        defer { scenario.defaults.tearDown() }
        await scenario.viewModel.run(.moreEnergy)
        let voice = scenario.writer.lastRewrite?.context.voice
        #expect(voice?.sounds == [.casual, .confident])
        #expect(voice?.vocabulary == nil)
        #expect(voice?.styles.isEmpty == true)
    }

    @Test func freeHooksComeFromTheFormatWithAIAsPro() async {
        let script = TestData.script(text: "Old hook.\n\nBody.")
        let scenario = makeScenario(script: script, tier: .free)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.locksHookVariations)
        await scenario.viewModel.openHooks()
        let first = scenario.viewModel.hookOptions
        #expect(first == ScriptTextEditing.hookOptions(from: ScriptStructure.generic.hooks, rotation: 0))
        await scenario.viewModel.showMoreHooks()
        #expect(scenario.viewModel.hookOptions != first)
        #expect(scenario.writer.hooksRequested == 0)
        scenario.viewModel.unlockHookVariations()
        #expect(scenario.viewModel.paywall == .hookVariations)
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
        #expect(scenario.toast.message == "Reels version saved as a copy")
    }

    @Test func versionsArePro() async {
        let script = TestData.script()
        let scenario = makeScenario(script: script, tier: .free)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.locksPlatformVersions)
        await scenario.viewModel.makeVersion(for: .shorts)
        #expect(scenario.viewModel.paywall == .platformVersions)
        #expect(scenario.library.scripts.count == 1)
    }

    @Test func destinationChangeAppliesThePreset() {
        let script = TestData.script(platform: .tiktok)
        let scenario = makeScenario(script: script)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.setPlatform(.youtube)
        #expect(scenario.library.script(id: script.id)?.platform == .youtube)
        #expect(scenario.viewModel.preset.prefersStudio)
    }
}
