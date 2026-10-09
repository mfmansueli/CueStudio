//
//  DiscoveryRulesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Which tools fit: requirements, a real object to try them on, and never a tool already used, declined or snoozed.
@Suite("DiscoveryRules")
struct DiscoveryRulesTests {
    private typealias F = NotificationFixtures
    private let monday = NotificationFixtures.monday

    private func offers(
        _ facts: NotificationFacts, state: NotificationState? = nil, channel: FeatureIntro.Channel = .notification
    ) -> [DiscoveryRules.Offer] {
        DiscoveryRules.offers(facts: facts, state: state ?? NotificationState(startedAt: monday), channel: channel).offers
    }

    private func features(_ facts: NotificationFacts, state: NotificationState? = nil, channel: FeatureIntro.Channel = .notification) -> [FeatureID] {
        offers(facts, state: state, channel: channel).map(\.intro.feature)
    }

    private var writer: NotificationFacts {
        var facts = NotificationFacts(now: monday)
        facts.scripts = [F.script(.draft), F.script(.draft)]
        facts.capabilities.aiWriting = true
        facts.profile.hasTopics = true
        return facts
    }

    @Test func nothingIsOfferedToSomeoneWhoHasMadeNothing() {
        #expect(features(NotificationFacts(now: monday)).isEmpty)
    }

    @Test func myCueVoiceIsForWritersWithAppleIntelligenceAndNoVoiceYet() {
        #expect(features(writer).first == .myCueVoice)
        #expect(offers(writer).first?.destination == .voiceSetup)
        var noAI = writer
        noAI.capabilities.aiWriting = false
        #expect(!features(noAI).contains(.myCueVoice))
        var configured = writer
        configured.profile.voiceConfigured = true
        #expect(!features(configured).contains(.myCueVoice))
        #expect(features(configured).contains(.importWriting))
    }

    @Test func aToolUsedDeclinedOrSnoozedIsOut() {
        var adopted = writer
        adopted.adopted = [.myCueVoice]
        #expect(!features(adopted).contains(.myCueVoice))
        var declined = NotificationState(startedAt: monday)
        declined.notInterested = [FeatureID.myCueVoice.rawValue]
        #expect(!features(writer, state: declined).contains(.myCueVoice))
        var snoozed = NotificationState(startedAt: monday)
        snoozed.snoozedFeatures[FeatureID.myCueVoice.rawValue] = monday + F.days(1)
        #expect(!features(writer, state: snoozed).contains(.myCueVoice))
        snoozed.snoozedFeatures[FeatureID.myCueVoice.rawValue] = monday - F.days(1)
        #expect(features(writer, state: snoozed).contains(.myCueVoice))
    }

    @Test func voiceFollowingNeedsAReadyScriptInALanguageThisIPhoneHears() {
        let ready = F.script(.ready, language: .english)
        var facts = NotificationFacts(now: monday)
        facts.scripts = [ready]
        #expect(!features(facts).contains(.voiceFollowing))
        facts.capabilities.voiceFollowing = [.english]
        #expect(offers(facts).first { $0.intro.feature == .voiceFollowing }?.destination == .voiceFollowing(scriptID: ready.id))
        facts.prompterIsSteady = false
        #expect(!features(facts).contains(.voiceFollowing))
    }

    @Test func cleanUpIsOfferedOnATakeLongEnoughThatWasNotListenedTo() {
        let take = F.take(scriptID: nil, duration: 40)
        var facts = NotificationFacts(now: monday)
        facts.takes = [take]
        facts.capabilities.captions = [.english]
        #expect(offers(facts).first { $0.intro.feature == .cleanUp }?.destination == .takeEditor(take.id, tool: .cleanUp))
        facts.takes = [F.take(scriptID: nil, duration: 6)]
        #expect(!features(facts).contains(.cleanUp))
        facts.takes = [F.take(scriptID: nil, duration: 40, analyzed: true)]
        #expect(!features(facts).contains(.cleanUp))
    }

    @Test func captionTranslationIsOnlyForCaptionsInALanguageWithAPair() {
        var facts = NotificationFacts(now: monday)
        facts.takes = [F.take(scriptID: nil, captions: true)]
        #expect(!features(facts).contains(.captionTranslation))
        facts.capabilities.captionTranslation = [.english]
        #expect(features(facts).contains(.captionTranslation))
    }

    @Test func remoteControlIsOnlyIntroducedInTheApp() {
        var facts = NotificationFacts(now: monday)
        facts.takes = [F.take(scriptID: nil)]
        #expect(!features(facts).contains(.remoteControl))
        #expect(features(facts, channel: .inApp).contains(.remoteControl))
    }

    @Test func toolsForAFinishedVideoWaitForOne() {
        var facts = NotificationFacts(now: monday)
        facts.takes = [F.take(scriptID: nil)]
        #expect(!features(facts).contains(.layers))
        facts.takes.append(F.take(scriptID: UUID(), stage: .shared, exported: true))
        #expect(features(facts).contains(.layers))
    }

    @Test func theToolShownFewestTimesComesFirst() {
        var state = NotificationState(startedAt: monday)
        state.exposures = [FeatureExposure(feature: .myCueVoice, date: monday - F.days(60), kind: .inApp)]
        let order = features(writer, state: state)
        #expect(order.first != .myCueVoice)
        #expect(order.contains(.myCueVoice))
    }
}
