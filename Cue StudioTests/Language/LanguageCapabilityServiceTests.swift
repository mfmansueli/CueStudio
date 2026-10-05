//
//  LanguageCapabilityServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What this device does in each language, feature by feature, asked once and kept.
@MainActor
@Suite("LanguageCapabilityService")
struct LanguageCapabilityServiceTests {
    /// The clock and the system's version, moved by the test.
    private final class Surroundings: @unchecked Sendable {
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        var system = "27.0|en-US"
    }

    private func makeService(
        _ checker: FakeLanguageCapabilityChecker, _ surroundings: Surroundings = Surroundings()
    ) -> LanguageCapabilityService {
        LanguageCapabilityService(checker: checker, now: { surroundings.now }, environment: { surroundings.system })
    }

    // MARK: - Independent features

    /// Apple Intelligence writing in a language says nothing about speech recognition in it.
    @Test func eachFeatureIsAskedAndAnsweredOnItsOwn() async {
        let checker = FakeLanguageCapabilityChecker()
        checker.set(.unavailable(.languageNotSupported), for: .aiWriting, .thai)
        checker.set(.supported, for: .voiceFollowing, .thai)
        checker.set(.notInstalled, for: .dictation, .thai)
        checker.set(.unavailable(.deviceNotSupported), for: .captions, .thai)
        let service = makeService(checker)
        let capabilities = await service.capabilities(of: .thai)
        #expect(capabilities[.interface] == .supported)
        #expect(capabilities[.aiWriting] == .unavailable(.languageNotSupported))
        #expect(capabilities[.voiceFollowing] == .supported)
        #expect(capabilities[.dictation] == .notInstalled)
        #expect(capabilities[.captions] == .unavailable(.deviceNotSupported))
        #expect(capabilities.unavailable.map(\.feature).sorted { $0.rawValue < $1.rawValue } == [.aiWriting, .captions])
    }

    @Test func supportedNotInstalledAndUnavailableAreThreeDifferentAnswers() {
        #expect(FeatureSupport.supported.isUsable && FeatureSupport.notInstalled.isUsable)
        #expect(!FeatureSupport.unavailable(.languageNotSupported).isUsable)
        #expect(FeatureSupport.supported != .notInstalled)
        #expect(VoiceFollowingAvailability(.supported) == .ready)
        #expect(VoiceFollowingAvailability(.notInstalled) == .downloadsOnFirstUse)
        #expect(VoiceFollowingAvailability(.unavailable(.turnedOff)) == .unavailable)
    }

    @Test func aFailingFeatureLeavesTheOthersAvailable() async {
        let checker = FakeLanguageCapabilityChecker()
        checker.set(.unavailable(.deviceNotSupported), for: .aiWriting, .english)
        let service = makeService(checker)
        #expect(await service.support(.aiWriting, for: .english) == .unavailable(.deviceNotSupported))
        #expect(await service.support(.voiceFollowing, for: .english) == .supported)
        #expect(await service.support(.captions, for: .english) == .supported)
    }

    // MARK: - Not asking again

    @Test func anAnswerIsKeptSoTheSystemIsNotAskedAgain() async {
        let checker = FakeLanguageCapabilityChecker()
        let service = makeService(checker)
        _ = await service.support(.voiceFollowing, for: .arabic)
        _ = await service.support(.voiceFollowing, for: .arabic)
        _ = await service.support(.voiceFollowing, for: .arabic)
        #expect(checker.asked == 1)
        #expect(service.known(.voiceFollowing, for: .arabic) == .supported)
        #expect(service.known(.voiceFollowing, for: .thai) == nil)
    }

    @Test func twoScreensAskingAtOnceShareOneQuestion() async {
        let checker = FakeLanguageCapabilityChecker()
        checker.setDelay(.milliseconds(100))
        let service = makeService(checker)
        async let first = service.support(.captions, for: .korean)
        async let second = service.support(.captions, for: .korean)
        let answers = await [first, second]
        #expect(answers == [.supported, .supported])
        #expect(checker.asked == 1)
    }

    /// A model that arrives, or Apple Intelligence turned on in Settings, changes within moments.
    @Test func notInstalledAndTurnedOffAreAskedAgainAfterAShortWhile() async {
        let checker = FakeLanguageCapabilityChecker()
        checker.set(.notInstalled, for: .voiceFollowing, .hindi)
        checker.set(.unavailable(.turnedOff), for: .aiWriting, .hindi)
        let surroundings = Surroundings()
        let service = makeService(checker, surroundings)
        #expect(await service.support(.voiceFollowing, for: .hindi) == .notInstalled)
        #expect(await service.support(.aiWriting, for: .hindi) == .unavailable(.turnedOff))
        surroundings.now.addTimeInterval(LanguageCapabilityService.volatileLifetime - 1)
        _ = await service.support(.voiceFollowing, for: .hindi)
        #expect(checker.asked == 2)
        checker.set(.supported, for: .voiceFollowing, .hindi)
        checker.set(.supported, for: .aiWriting, .hindi)
        surroundings.now.addTimeInterval(2)
        #expect(await service.support(.voiceFollowing, for: .hindi) == .supported)
        #expect(await service.support(.aiWriting, for: .hindi) == .supported)
    }

    @Test func whatOnlyAnUpdateChangesIsKeptUntilTheSystemChanges() async {
        let checker = FakeLanguageCapabilityChecker()
        checker.set(.unavailable(.languageNotSupported), for: .aiWriting, .thai)
        let surroundings = Surroundings()
        let service = makeService(checker, surroundings)
        _ = await service.support(.aiWriting, for: .thai)
        surroundings.now.addTimeInterval(24 * 3600)
        _ = await service.support(.aiWriting, for: .thai)
        #expect(checker.asked == 1)
        // The system was updated (or the iPhone's languages changed): ask again.
        surroundings.system = "27.1|en-US"
        checker.set(.supported, for: .aiWriting, .thai)
        #expect(await service.support(.aiWriting, for: .thai) == .supported)
        #expect(checker.asked == 2)
    }

    @Test func invalidatingAsksAgain() async {
        let checker = FakeLanguageCapabilityChecker()
        let service = makeService(checker)
        _ = await service.support(.dictation, for: .french)
        service.invalidate()
        _ = await service.support(.dictation, for: .french)
        #expect(checker.asked == 2)
    }

    // MARK: - Translation

    @Test func translationIsAskedPerPairAndKept() async {
        let checker = FakeLanguageCapabilityChecker()
        checker.setTranslation(.notInstalled)
        let service = makeService(checker)
        let portuguese = Locale.Language(identifier: "pt")
        #expect(await service.translation(from: portuguese, to: .german) == .notInstalled)
        #expect(await service.translation(from: portuguese, to: .german) == .notInstalled)
        #expect(checker.asked == 1)
        _ = await service.translation(from: portuguese, to: .french)
        #expect(checker.asked == 2)
        // Traditional and Simplified Chinese are different targets.
        _ = await service.translation(from: portuguese, to: .chineseSimplified)
        _ = await service.translation(from: portuguese, to: .chineseTraditional)
        #expect(checker.asked == 4)
    }
}
