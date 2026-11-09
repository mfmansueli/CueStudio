//
//  TakesFirstStarTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// D4: the first star of a review left without a confirmed post lights on that video's card in Takes, once, and counts as a celebration for
/// the gate (the notifications' invitation doesn't follow it in the same session).
@MainActor
@Suite("Takes · the first star")
struct TakesFirstStarTests {
    private struct Scenario {
        let viewModel: TakesViewModel
        let takes: TakeLibraryService
        let onboarding: OnboardingService
        let guidance: GuidanceGate
        let defaults: TestDefaults
    }

    private func makeScenario(_ recorded: [Take]) -> Scenario {
        let defaults = TestDefaults()
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: recorded))
        takes.load()
        let onboarding = OnboardingService(defaults: defaults.defaults, isEnabled: false)
        let guidance = GuidanceGate()
        let viewModel = TakesViewModel(
            takes: takes, library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])), drafts: FakeDraftStore(),
            presentation: PresentationService(), toast: ToastService(), onboarding: onboarding, guidance: guidance, now: { TestData.now }
        )
        return Scenario(viewModel: viewModel, takes: takes, onboarding: onboarding, guidance: guidance, defaults: defaults)
    }

    @Test func theWaitingStarLightsOnItsVideoOnceAndIsTold() throws {
        let take = TestData.take(scriptID: UUID())
        let scenario = makeScenario([take])
        defer { scenario.defaults.tearDown() }
        #expect(!scenario.viewModel.lightFirstStar(), "nothing waits")
        scenario.onboarding.keepFirstStar(for: take.id)
        #expect(scenario.viewModel.lightFirstStar())
        #expect(scenario.viewModel.firstStarVideoID == scenario.viewModel.allVideos.first?.id)
        #expect(scenario.onboarding.firstStarShown && scenario.onboarding.firstStarWaitingTake == nil)
        #expect(scenario.guidance.celebratedThisSession, "the gate knows a celebration played")
        #expect(!scenario.viewModel.lightFirstStar(), "lit once")
        #expect(scenario.viewModel.firstStarVideoID != nil, "and it stays on the card")
    }

    @Test func aDeletedTakesStarWaitsUntoldForTheNextReview() {
        let take = TestData.take(scriptID: UUID())
        let scenario = makeScenario([take])
        defer { scenario.defaults.tearDown() }
        scenario.onboarding.keepFirstStar(for: take.id)
        scenario.takes.delete(take.id)
        #expect(!scenario.viewModel.lightFirstStar())
        #expect(scenario.onboarding.firstStarWaitingTake == nil && !scenario.onboarding.firstStarShown)
        #expect(!scenario.guidance.celebratedThisSession)
    }

    @Test func aVideoFilteredOutOfTheListWaitsUntilItShows() {
        let take = TestData.take(scriptID: UUID())
        let scenario = makeScenario([take])
        defer { scenario.defaults.tearDown() }
        scenario.onboarding.keepFirstStar(for: take.id)
        scenario.viewModel.toggle(.shared)
        #expect(!scenario.viewModel.lightFirstStar(), "not on screen: it waits")
        #expect(scenario.onboarding.firstStarWaitingTake == take.id)
        scenario.viewModel.toggle(.shared)
        #expect(scenario.viewModel.lightFirstStar())
    }
}
