//
//  OnboardingViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The first flight's work between the chapters: the first script, the permissions and the end.
@MainActor
@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {
    private struct Scenario {
        let model: OnboardingViewModel
        let onboarding: OnboardingService
        let writer: FakeScriptWriter
        let permissions: StubPermissions
        let library: ScriptLibraryService
        let profile: CreatorProfileService
        let ideaDraft: IdeaDraftService
        let presentation: PresentationService
        let defaults: TestDefaults
    }

    private func make(grants: Bool = true, aiAvailable: Bool = true) -> Scenario {
        let defaults = TestDefaults()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []), now: { TestData.now })
        library.load()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        let languages = TestData.languages(defaults: defaults.defaults)
        let writer = FakeScriptWriter()
        writer.isAvailable = aiAvailable
        let onboarding = OnboardingService(defaults: defaults.defaults)
        onboarding.resolve(hasExistingContent: false)
        let ideaDraft = IdeaDraftService()
        let presentation = PresentationService()
        let permissions = StubPermissions(grants: grants)
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: profile, scriptLanguage: nil, interfaceLanguage: nil
        )
        _ = languages
        let model = OnboardingViewModel(
            onboarding: onboarding, writer: writer, factory: factory, permissions: permissions, library: library,
            profile: profile, ideaDraft: ideaDraft, presentation: presentation
        )
        return Scenario(
            model: model, onboarding: onboarding, writer: writer, permissions: permissions, library: library,
            profile: profile, ideaDraft: ideaDraft, presentation: presentation, defaults: defaults
        )
    }

    // MARK: - The first script

    @Test func theModelWritesAFifteenSecondScriptInTheTopicForThePlatform() async {
        let scenario = make()
        defer { scenario.defaults.tearDown() }
        scenario.onboarding.toggle(.niche(.fitness))
        scenario.onboarding.platform = .reels
        scenario.model.writeScript()
        #expect(scenario.model.scriptState == .writing)
        await Wait.until { scenario.model.scriptState == .ready }
        #expect(scenario.model.scriptState == .ready)
        let request = scenario.writer.lastRequest
        #expect(request?.platform == .reels)
        #expect(request?.targetRange == 12...18)
        if case .prompt(let idea) = request?.source { #expect(idea.contains("Fitness")) } else { Issue.record("a free prompt") }
        #expect(scenario.model.script?.isCurated == false)
        #expect(scenario.model.script?.hook == "Hey there. [pause]")
    }

    @Test func withoutAModelTheScriptIsOursAndLabelledAsPractice() {
        let scenario = make(aiAvailable: false)
        defer { scenario.defaults.tearDown() }
        scenario.onboarding.addCustom("Budget travel")
        scenario.model.writeScript()
        #expect(scenario.model.scriptState == .ready)
        #expect(scenario.model.script?.isCurated == true)
        #expect(scenario.model.script?.hook.contains("Budget travel") == true)
        #expect(scenario.writer.lastRequest == nil, "the model is never called")
    }

    @Test func aFailureFallsBackToOurScriptInsteadOfStoppingTheFlight() async {
        let scenario = make()
        defer { scenario.defaults.tearDown() }
        scenario.writer.error = ScriptAIError.emptyResponse
        scenario.model.writeScript()
        await Wait.until { scenario.model.scriptState == .ready }
        #expect(scenario.model.scriptState == .ready && scenario.model.script?.isCurated == true)
    }

    @Test func anotherAsksAgainAndCountsTheAttempts() {
        let scenario = make(aiAvailable: false)
        defer { scenario.defaults.tearDown() }
        scenario.model.writeScript()
        scenario.model.writeScript()
        #expect(scenario.model.attempts == 2)
    }

    // MARK: - Permissions

    @Test func theMicrophoneIsAskedFirstThenSpeechThenTheCamera() async {
        let scenario = make()
        defer { scenario.defaults.tearDown() }
        #expect(!scenario.model.hasAnsweredEverything)
        await scenario.model.askPermissions()
        #expect(scenario.model.microphone == .allowed && scenario.model.speech == .allowed && scenario.model.camera == .allowed)
        #expect(scenario.model.hasAnsweredEverything)
    }

    @Test func aRefusalNeverBlocksTheFlightAndSpeechIsNotAskedWithoutTheMicrophone() async {
        let scenario = make(grants: false)
        defer { scenario.defaults.tearDown() }
        await scenario.model.askPermissions()
        #expect(scenario.model.microphone == .denied && scenario.model.camera == .denied)
        #expect(scenario.model.speech == .notAsked)
        #expect(scenario.model.hasAnsweredEverything, "answered, so the flight goes on")
    }

    @Test func eachRowAsksOnlyForItsOwnPermission() async {
        let scenario = make()
        defer { scenario.defaults.tearDown() }
        await scenario.model.askCamera()
        #expect(scenario.model.camera == .allowed)
        #expect(scenario.model.microphone == .notAsked && scenario.model.speech == .notAsked)
        await scenario.model.askMicrophone()
        #expect(scenario.model.microphone == .allowed && scenario.model.speech == .allowed)
        #expect(scenario.model.hasAnsweredEverything)
        #expect(!scenario.model.hasDenied)
    }

    @Test func aRefusedPermissionIsReportedSoTheScreenCanPointToSettings() async {
        let scenario = make(grants: false)
        defer { scenario.defaults.tearDown() }
        #expect(!scenario.model.hasDenied)
        await scenario.model.askMicrophone()
        #expect(scenario.model.hasDenied)
        #expect(scenario.model.camera == .notAsked, "the other row is still open")
        await scenario.model.askCamera()
        #expect(scenario.model.hasAnsweredEverything, "a refusal still lets the flight go on")
    }

    // MARK: - The end

    @Test func theChoicesGoWhereTheAppReadsThem() {
        let scenario = make()
        defer { scenario.defaults.tearDown() }
        scenario.onboarding.toggle(.niche(.food))
        scenario.onboarding.addCustom("Budget travel")
        scenario.onboarding.platform = .shorts
        scenario.model.applyChoices()
        #expect(scenario.profile.profile.niches == [.food])
        #expect(scenario.profile.profile.customTopics == ["Budget travel"])
        #expect(scenario.profile.profile.defaultPlatform == .shorts)
        #expect(scenario.ideaDraft.platform == .shorts)
    }

    @Test func nothingPickedLeavesTheProfileAsItWas() {
        let scenario = make()
        defer { scenario.defaults.tearDown() }
        scenario.model.applyChoices()
        #expect(scenario.profile.profile.niches.isEmpty && scenario.profile.profile.customTopics.isEmpty)
    }

    @Test func usingTheScriptMakesARealOneForThePlatform() {
        let scenario = make(aiAvailable: false)
        defer { scenario.defaults.tearDown() }
        scenario.onboarding.platform = .youtube
        scenario.model.writeScript()
        let created = scenario.model.keepScript()
        #expect(created?.platform == .youtube)
        #expect(scenario.library.scripts.count == 1)
        #expect(scenario.library.scripts.first?.text == scenario.model.script?.text)
    }

    @Test func finishingKeepsThePicksEndsTheFlightAndOpensScripts() {
        let scenario = make()
        defer { scenario.defaults.tearDown() }
        scenario.onboarding.toggle(.niche(.tech))
        scenario.presentation.selectedTab = .profile
        scenario.model.finish()
        #expect(scenario.onboarding.isCompleted)
        #expect(scenario.profile.profile.niches == [.tech])
        #expect(scenario.presentation.selectedTab == .scripts)
    }

    @Test func profilesSavedBeforeCustomTopicsStillOpen() throws {
        let json = #"{"name":"Ana","niches":["food"]}"#
        let profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(json.utf8))
        #expect(profile.customTopics.isEmpty && profile.niches == [.food])
        let round = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(round.voiceSchemaVersion == CreatorProfile.currentVoiceSchema, "what this build writes is of the current version")
        var expected = profile
        expected.voiceSchemaVersion = round.voiceSchemaVersion
        #expect(round == expected)
    }
}
