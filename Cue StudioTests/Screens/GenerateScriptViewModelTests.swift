//
//  GenerateScriptViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("GenerateScriptViewModel")
struct GenerateScriptViewModelTests {
    private struct Scenario {
        let viewModel: GenerateScriptViewModel
        let writer: FakeScriptWriter
        let library: ScriptLibraryService
        let profile: CreatorProfileService
        let defaults: TestDefaults
    }

    private func makeScenario(tab: GenerateTab = .prompt) -> Scenario {
        let defaults = TestDefaults()
        let writer = FakeScriptWriter()
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.addPhrase("Hey fam")
        // A voice the creator set up: the defaults a new profile starts with are never applied.
        profile.saveVoiceSetup(niches: [.tech], vocabulary: .simple, sounds: [.casual])
        let viewModel = GenerateScriptViewModel(
            initialTab: tab, writer: writer, library: library, profile: profile, rules: TestData.rulesService(),
            toast: ToastService()
        )
        return Scenario(viewModel: viewModel, writer: writer, library: library, profile: profile, defaults: defaults)
    }

    // MARK: - Prompt

    @Test func promptWritesAScriptInTheCreatorsVoice() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.promptText = "Why I quit coffee for 30 days"
        scenario.viewModel.platform = .reels
        let script = await scenario.viewModel.generateFromPrompt()
        #expect(script?.platform == .reels)
        #expect(script?.type == nil)
        #expect(script?.factCheck == false)
        #expect(scenario.writer.lastRequest?.voice?.phrases == ["Hey fam"])
        #expect(scenario.writer.lastRequest?.source == .prompt("Why I quit coffee for 30 days"))
    }

    @Test func factualPromptsAreFlaggedForAFactCheck() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.promptText = GenerateScriptViewModel.examples[0]
        let script = await scenario.viewModel.generateFromPrompt()
        #expect(script?.factCheck == true)
        #expect(scenario.library.scripts.first?.factCheck == true)
    }

    @Test func twoMinutesAimsForAboutThreeHundredWords() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.promptText = "My morning routine"
        scenario.viewModel.length = .minutes2
        _ = await scenario.viewModel.generateFromPrompt()
        let range = scenario.writer.lastRequest?.targetRange
        #expect(range.map { abs(ReadTime.words(for: $0.lowerBound) - 270) <= 2 } == true)
        #expect(range.map { abs(ReadTime.words(for: $0.upperBound) - 330) <= 2 } == true)
    }

    @Test func autoLengthReadsTheLengthFromThePrompt() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.promptText = "3 minutes on the history of the teleprompter"
        _ = await scenario.viewModel.generateFromPrompt()
        #expect(scenario.writer.lastRequest?.targetRange == 162...198)
    }

    @Test func autoLengthFollowsThePlatformsIdealRange() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.promptText = "My desk setup"
        scenario.viewModel.platform = .tiktok
        _ = await scenario.viewModel.generateFromPrompt()
        #expect(scenario.writer.lastRequest?.targetRange == 60...90)
    }

    @Test func voiceCanBeTurnedOff() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.promptText = "My desk setup"
        scenario.viewModel.writesInMyVoice = false
        _ = await scenario.viewModel.generateFromPrompt()
        #expect(scenario.writer.lastRequest?.voice == nil)
    }

    @Test func theVoiceIsNeverAppliedFromTheDefaultsOfANewProfile() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        let freshStore = TestDefaults()
        defer { freshStore.tearDown() }
        let fresh = CreatorProfileService(defaults: freshStore.defaults)
        let viewModel = GenerateScriptViewModel(
            writer: scenario.writer, library: scenario.library, profile: fresh, rules: TestData.rulesService(), toast: ToastService()
        )
        // The switch is nominally on (the profile's default), but there is nothing of the creator to write like.
        #expect(fresh.profile.usesVoiceInAI)
        #expect(!viewModel.writesInMyVoice)
        #expect(viewModel.voiceSummary == "Set up your voice in Profile")
        viewModel.promptText = "My desk setup"
        _ = await viewModel.generateFromPrompt()
        #expect(scenario.writer.lastRequest?.voice == nil)
        // It can't be switched on from here either: the setup has to run first.
        viewModel.writesInMyVoice = true
        #expect(!viewModel.writesInMyVoice)
    }

    @Test func theVoiceSwitchIsTheProfilesSharedState() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.writesInMyVoice)
        // Turned off on this screen, it is off everywhere that reads the profile (the card, Profile).
        scenario.viewModel.writesInMyVoice = false
        #expect(!scenario.profile.writesInMyVoice && !scenario.profile.profile.usesVoiceInAI)
        // Turned on from the card or Profile, it is on here.
        #expect(scenario.profile.setWritesInMyVoice(true))
        #expect(scenario.viewModel.writesInMyVoice)
        scenario.viewModel.promptText = "My desk setup"
        _ = await scenario.viewModel.generateFromPrompt()
        #expect(scenario.writer.lastRequest?.voice?.niches == [.tech])
        #expect(scenario.writer.lastRequest?.voice?.sounds == [.casual])
    }

    @Test func emptyPromptDoesNothing() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.promptText = "   "
        #expect(await scenario.viewModel.generateFromPrompt() == nil)
        #expect(scenario.writer.lastRequest == nil)
    }

    @Test func withoutAppleIntelligenceThePromptExplainsWhy() async {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.writer.isAvailable = false
        scenario.viewModel.promptText = "My desk setup"
        #expect(!scenario.viewModel.canWriteFromPrompt)
        #expect(await scenario.viewModel.generateFromPrompt() == nil)
        #expect(scenario.viewModel.errorMessage == "Requires Apple Intelligence.")
        #expect(scenario.library.scripts.isEmpty)
    }

    @Test func examplesFillThePromptAndItsLength() {
        let scenario = makeScenario()
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.useExample(GenerateScriptViewModel.examples[0])
        #expect(scenario.viewModel.promptText == GenerateScriptViewModel.examples[0])
        #expect(scenario.viewModel.length == .minutes2)
    }

    // MARK: - Themes

    @Test func themesStartWithTheStarterIdeasForTheNiche() {
        let scenario = makeScenario(tab: .themes)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.tab == .themes)
        #expect(scenario.viewModel.themes.count == 3)
        #expect(scenario.viewModel.themeNiches == "Lifestyle")
    }

    @Test func usingAThemeFillsThePrompt() {
        let scenario = makeScenario(tab: .themes)
        defer { scenario.defaults.tearDown() }
        let idea = scenario.viewModel.themes[0]
        scenario.viewModel.useTheme(idea)
        #expect(scenario.viewModel.tab == .prompt)
        #expect(scenario.viewModel.promptText == "1 min list video: 3 things I stopped buying this year")
        #expect(scenario.viewModel.length == .minute1)
    }

    @Test func newIdeasComeFromTheModel() async {
        let scenario = makeScenario(tab: .themes)
        defer { scenario.defaults.tearDown() }
        scenario.writer.ideas = [ThemeIdea(title: "Fresh idea", kind: "List", length: .minute1, niche: .tech)]
        await scenario.viewModel.loadNewIdeas()
        #expect(scenario.viewModel.themes.map(\.title) == ["Fresh idea"])
    }

    @Test func withoutTheModelNewIdeasRotateTheStarterIdeas() async {
        let scenario = makeScenario(tab: .themes)
        defer { scenario.defaults.tearDown() }
        scenario.writer.isAvailable = false
        let before = scenario.viewModel.themes.first
        await scenario.viewModel.loadNewIdeas()
        #expect(scenario.viewModel.themes.first != before)
    }

    // MARK: - Formats

    @Test func formatBriefWritesAStructuredScript() async {
        let scenario = makeScenario(tab: .formats)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.choose(.list)
        scenario.viewModel.platform = .reels
        let script = await scenario.viewModel.generateFromBrief()
        #expect(script?.type == .list)
        #expect(script?.platform == .reels)
        #expect(scenario.library.scripts.count == 1)
        #expect(scenario.writer.lastRequest?.voice?.phrases == ["Hey fam"])
    }

    @Test func seriousFormatsNeverUseTheVoice() async {
        let scenario = makeScenario(tab: .formats)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.choose(.apology)
        _ = await scenario.viewModel.generateFromBrief()
        #expect(scenario.writer.lastRequest?.voice == nil)
    }

    @Test func sponsoredAdIsFree() async {
        let scenario = makeScenario(tab: .formats)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.choose(.ad)
        #expect(scenario.viewModel.selectedType == .ad)
        let script = await scenario.viewModel.generateFromBrief()
        #expect(script?.type == .ad)
    }

    @Test func withoutTheModelFormatsStillGetTheStructuredDraft() async {
        let scenario = makeScenario(tab: .formats)
        defer { scenario.defaults.tearDown() }
        scenario.writer.isAvailable = false
        scenario.viewModel.choose(.review)
        let script = await scenario.viewModel.generateFromBrief()
        #expect(script != nil)
        #expect(scenario.viewModel.modelNote != nil)
    }

    @Test func choosingAFormatResetsTheBriefAndPicksAMatchingTone() {
        let scenario = makeScenario(tab: .formats)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.choose(.ad)
        scenario.viewModel.setValue("Brand", for: ScriptType.ad.briefFields[0])
        scenario.viewModel.choose(.apology)
        #expect(scenario.viewModel.brief.isEmpty)
        #expect(scenario.viewModel.tone == .sincere)
    }

    @Test func toneFollowsHowTheCreatorSounds() {
        let scenario = makeScenario(tab: .formats)
        defer { scenario.defaults.tearDown() }
        scenario.profile.profile.sounds = [.confident, .energetic]
        scenario.viewModel.choose(.review)
        #expect(scenario.viewModel.tone == .energetic)
    }

    // MARK: - Writing: once, cancelable, retryable

    /// Where the scripts a request created end up.
    private final class Created {
        var scripts: [Script] = []
    }

    private struct GatedScenario {
        let viewModel: GenerateScriptViewModel
        let writer: GatedScriptWriter
        let library: ScriptLibraryService
        let created = Created()
        let defaults: TestDefaults
    }

    private func makeGatedScenario() -> GatedScenario {
        let defaults = TestDefaults()
        let writer = GatedScriptWriter()
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let viewModel = GenerateScriptViewModel(
            writer: writer, library: library, profile: CreatorProfileService(defaults: defaults.defaults),
            rules: TestData.rulesService(), toast: ToastService()
        )
        viewModel.promptText = "My desk setup"
        return GatedScenario(viewModel: viewModel, writer: writer, library: library, defaults: defaults)
    }

    /// Lets the tasks the view model started run until `condition` holds.
    private func wait(until condition: () -> Bool) async {
        for _ in 0..<300 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func openingTheScreenWritesNothing() async {
        let scenario = makeGatedScenario()
        defer { scenario.defaults.tearDown() }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(scenario.writer.started == 0 && !scenario.viewModel.isGenerating)
    }

    @Test func askingAgainWhileWritingStartsOnlyOneRequest() async {
        let scenario = makeGatedScenario()
        defer { scenario.defaults.tearDown() }
        let created = scenario.created
        scenario.viewModel.startPromptGeneration { created.scripts.append($0) }
        scenario.viewModel.startPromptGeneration { created.scripts.append($0) }
        await wait { scenario.writer.started > 0 }
        #expect(scenario.writer.started == 1 && scenario.viewModel.isGenerating)
        scenario.writer.release()
        await wait { !scenario.viewModel.isGenerating && !created.scripts.isEmpty }
        #expect(scenario.writer.started == 1 && scenario.writer.finished == 1)
        #expect(created.scripts.count == 1 && scenario.library.scripts.count == 1)
        #expect(!scenario.viewModel.isGenerating && scenario.viewModel.errorMessage == nil)
    }

    @Test func cancellingEndsTheLoadingWithoutAScriptOrAnError() async {
        let scenario = makeGatedScenario()
        defer { scenario.defaults.tearDown() }
        let created = scenario.created
        scenario.viewModel.startPromptGeneration { created.scripts.append($0) }
        await wait { scenario.writer.started > 0 }
        #expect(scenario.viewModel.isGenerating)
        scenario.viewModel.cancelGeneration()
        #expect(!scenario.viewModel.isGenerating)
        await wait { scenario.writer.cancelled > 0 }
        #expect(scenario.writer.cancelled == 1)
        #expect(created.scripts.isEmpty && scenario.library.scripts.isEmpty)
        #expect(scenario.viewModel.errorMessage == nil && !scenario.viewModel.isGenerating)
    }

    @Test func aRequestCanBeAskedAgainRightAfterACancellation() async {
        let scenario = makeGatedScenario()
        defer { scenario.defaults.tearDown() }
        let created = scenario.created
        scenario.viewModel.startPromptGeneration { created.scripts.append($0) }
        await wait { scenario.writer.started == 1 }
        scenario.viewModel.cancelGeneration()
        scenario.viewModel.startPromptGeneration { created.scripts.append($0) }
        await wait { scenario.writer.started == 2 }
        #expect(scenario.writer.started == 2 && scenario.viewModel.isGenerating)
        scenario.writer.release()
        await wait { !created.scripts.isEmpty }
        // The cancelled one never makes a script, and its end doesn't end the new one's loading early.
        #expect(created.scripts.count == 1)
        await wait { !scenario.viewModel.isGenerating }
        #expect(!scenario.viewModel.isGenerating)
    }

    @Test func aFailureEndsTheLoadingSaysWhyAndCanBeTriedAgain() async {
        let scenario = makeGatedScenario()
        defer { scenario.defaults.tearDown() }
        let created = scenario.created
        scenario.writer.failure = ScriptAIError.emptyResponse
        scenario.writer.release()
        scenario.viewModel.startPromptGeneration { created.scripts.append($0) }
        await wait { scenario.viewModel.errorMessage != nil }
        #expect(scenario.viewModel.errorMessage == ScriptAIError.emptyResponse.errorDescription)
        await wait { !scenario.viewModel.isGenerating }
        #expect(!scenario.viewModel.isGenerating && created.scripts.isEmpty)
        // Trying again runs the same request again, once, and clears the message.
        scenario.writer.failure = nil
        scenario.viewModel.retryGeneration { created.scripts.append($0) }
        await wait { !created.scripts.isEmpty }
        #expect(scenario.writer.started == 2 && created.scripts.count == 1)
        #expect(scenario.viewModel.errorMessage == nil)
    }
}

