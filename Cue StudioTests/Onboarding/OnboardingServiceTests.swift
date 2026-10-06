//
//  OnboardingServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The first flight: its steps, the topics it collects and who sees it.
@MainActor
@Suite("OnboardingService")
struct OnboardingServiceTests {
    private func make(enabled: Bool = true, defaults: TestDefaults = TestDefaults()) -> (OnboardingService, TestDefaults) {
        (OnboardingService(defaults: defaults.defaults, isEnabled: enabled), defaults)
    }

    @Test func aFreshInstallSeesTheFlightOnceTheLibraryIsRead() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        #expect(!service.isActive, "nothing shows before the library is looked at")
        service.resolve(hasExistingContent: false)
        #expect(service.isActive)
    }

    @Test func aCreatorWhoAlreadyUsesCueNeverSeesIt() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        service.resolve(hasExistingContent: true)
        #expect(!service.isActive && service.isCompleted)
        #expect(OnboardingService(defaults: defaults.defaults).isCompleted, "and it stays that way")
    }

    @Test func whenItIsTurnedOffItNeverShows() {
        let (service, defaults) = make(enabled: false)
        defer { defaults.tearDown() }
        service.resolve(hasExistingContent: false)
        #expect(!service.isActive)
    }

    @Test func theStepsRunWelcomeThenFiveChaptersAndTheBarLightsOneSegmentEach() {
        #expect(OnboardingStep.allCases == [.welcome, .universe, .voyage, .script, .voice, .practice])
        #expect(OnboardingStep.welcome.segment == nil)
        #expect(OnboardingStep.allCases.dropFirst().map(\.segment) == [0, 1, 2, 3, 3], "the practice lights the permissions' segment, as the boards do")
        #expect(OnboardingStep.segmentCount == 5)
        #expect(OnboardingStep.practice.next == nil)
    }

    @Test func advancingWalksTheChaptersAndTheLastOneEndsTheFlight() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        service.resolve(hasExistingContent: false)
        for expected in [OnboardingStep.universe, .voyage, .script, .voice, .practice] {
            service.advance()
            #expect(service.step == expected)
        }
        service.advance()
        #expect(service.isCompleted)
    }

    @Test func backGoesToTheChapterBeforeAndStopsAtTheWelcome() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        service.advance()
        service.advance()
        service.back()
        #expect(service.step == .universe)
        service.back()
        service.back()
        #expect(service.step == .welcome)
    }

    // MARK: - Topics

    @Test func atMostThreeTopicsAndAFourthIsNotTakenUntilOneIsLetGo() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        [Niche.fitness, .food, .tech].forEach { service.toggle(.niche($0)) }
        #expect(service.topics.count == 3 && service.isFull)
        #expect(!service.toggle(.niche(.finance)))
        #expect(service.topics == [.niche(.fitness), .niche(.food), .niche(.tech)])
        // Letting one go makes room for another, which takes the free colour (the last place).
        #expect(!service.toggle(.niche(.fitness)))
        #expect(service.toggle(.niche(.finance)))
        #expect(service.topics == [.niche(.food), .niche(.tech), .niche(.finance)])
        #expect(service.mainTopic == .niche(.food))
    }

    @Test func tappingAPickedTopicLetsItGo() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        service.toggle(.niche(.fitness))
        #expect(service.canContinueFromTopics)
        service.toggle(.niche(.fitness))
        #expect(service.topics.isEmpty && !service.canContinueFromTopics)
    }

    @Test func aTopicOfTheirOwnIsKeptTrimmedAndBlankOnesAreIgnored() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        service.addCustom("   ")
        #expect(service.topics.isEmpty)
        service.addCustom("  Budget travel ")
        #expect(service.topics == [.custom("Budget travel")])
        service.addCustom("budget travel")
        #expect(service.topics.count == 1, "the same name isn't added twice")
        service.addCustom(String(repeating: "x", count: 80))
        #expect(service.topics.last?.label.count == 28)
    }

    @Test func eachTopicHasAColorByItsPlaceInTheUniverse() {
        #expect(OnboardingTopic.limit == 3)
        #expect(OnboardingTopic.niche(.food).id != OnboardingTopic.custom("Food").id)
    }

    @Test func theFirstStarIsToldOnce() {
        let (service, defaults) = make()
        defer { defaults.tearDown() }
        #expect(!service.firstStarShown)
        service.markFirstStarShown()
        #expect(OnboardingService(defaults: defaults.defaults).firstStarShown)
    }
}
