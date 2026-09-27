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

    private func makeScenario(tier: MembershipTier = .free, tab: GenerateTab = .prompt) -> Scenario {
        let defaults = TestDefaults()
        let writer = FakeScriptWriter()
        let library = ScriptLibraryService(repository: FakeScriptRepository(), now: { TestData.now })
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.addPhrase("Hey fam")
        let viewModel = GenerateScriptViewModel(
            initialTab: tab, writer: writer, library: library, profile: profile, rules: TestData.rulesService(),
            tier: { tier }, toast: ToastService()
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
        #expect(range.map { ReadTime.words(for: $0.lowerBound) } == 270)
        #expect(range.map { ReadTime.words(for: $0.upperBound) } == 330)
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

    @Test func sponsoredAdOpensThePaywallOnTheFreePlan() async {
        let scenario = makeScenario(tab: .formats)
        defer { scenario.defaults.tearDown() }
        #expect(scenario.viewModel.isLocked(.ad))
        scenario.viewModel.choose(.ad)
        #expect(scenario.viewModel.selectedType == nil)
        #expect(scenario.viewModel.paywall == .sponsoredAd)
    }

    @Test func sponsoredAdIsOpenOnPro() {
        let scenario = makeScenario(tier: .subscriber, tab: .formats)
        defer { scenario.defaults.tearDown() }
        scenario.viewModel.choose(.ad)
        #expect(scenario.viewModel.selectedType == .ad)
        #expect(scenario.viewModel.paywall == nil)
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
        let scenario = makeScenario(tier: .subscriber, tab: .formats)
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
}
