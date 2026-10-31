//
//  UltraCostDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// What an Ultra AI script really costs, on the iPhone, from the three places a creator starts one, in Portuguese, English and Spanish: the idea
/// the card in Scripts suggests (Apple Intelligence writes the card's ideas on this iPhone, as the app does, for a made-up finance and habits
/// creator), the next idea as Find inspiration offers it ("Draft with Ultra AI"), and an idea typed on the dock. Each script runs the app's flow
/// (draft, check, polish, and the fit when it comes back past TikTok's range), and its cost is Google's own usage in each answer at
/// `UltraPrice` (`UltraCost`), printed as `COST …` lines and kept as attachments (`ultra-cost-<language>-<source>.json`). Synthetic data only,
/// counted in the lab's 300 calls; about nine to twelve calls a language.
///
/// `CUE_DEVICE="iago Lima iphone" scripts/test.sh device UltraCostDeviceTests` (`TEST_RUNNER_CUE_ULTRA_E2E=1`), the iPhone unlocked;
/// `TEST_RUNNER_CUE_ULTRA_COST_LANGUAGES=pt,es` narrows it.
@MainActor
@Suite("Ultra AI's cost on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_ULTRA_E2E"] != nil))
struct UltraCostDeviceTests {
    private static let languages = ProcessInfo.processInfo.environment["CUE_ULTRA_COST_LANGUAGES"]
        .map { Set($0.split(separator: ",").map(String.init)) }

    nonisolated enum Language: String, CaseIterable, Sendable {
        case pt, en, es

        var cue: CueLanguage {
            switch self {
            case .pt: .portugueseBrazil
            case .en: .english
            case .es: .spanish
            }
        }

        /// The idea typed on the dock.
        var typed: String {
            switch self {
            case .pt: "Como eu organizo a semana inteira em 20 minutos no domingo, sem aplicativo nenhum"
            case .en: "The three questions I ask myself before buying anything over fifty dollars"
            case .es: "Lo que aprendí cocinando para toda la semana con un presupuesto de 30 euros"
            }
        }
    }

    private struct Sample: Encodable {
        let language: String
        let source: String
        let idea: String
        /// The card's idea came from the model (with an angle and an opening line), not from the starters.
        let ideaFromModel: Bool?
        let title: String
        let script: String
        let words: Int
        let estimatedSeconds: Double
        let calls: Int
        let inputTokens: Int
        let cachedTokens: Int
        let outputTokens: Int
        let thinkingTokens: Int
        let dollars: Double
        let seconds: Double
        let perCall: [[Int?]]
        let failure: String?
    }

    /// A made-up creator: personal finance and habits, every kind of voice preference, no private samples.
    private static var voice: CreatorVoice {
        var voice = CreatorVoice(sounds: [.casual, .confident], phrases: [], vocabulary: .simple, styles: [], niches: [.finance, .lifestyle])
        voice.role = .educator
        voice.style.sentences = .short
        voice.style.energy = .high
        voice.endings = ["Ask a question to the audience"]
        voice.avoid = ["get-rich-quick promises"]
        return voice
    }

    @Test(.timeLimit(.minutes(5)), arguments: Language.allCases)
    func threeStarts(_ language: Language) async throws {
        guard Self.languages?.contains(language.rawValue) ?? true else { return }
        KeepScreenAwake.enable()
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        try #require(UltraLabConfiguration.isPresent, "Copy the lab's configuration into the app's Documents first")
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile.niches = [.finance, .lifestyle]

        // The card's ideas, as the app asks Apple Intelligence for them (the starters when it can't).
        let writer = ScriptAIService()
        let suggestions = IdeaSuggestionService(
            writer: writer, profile: profile, interfaceLanguage: { language.cue }, defaults: defaults.defaults
        )
        if writer.availability.onDevice { await suggestions.refill() }
        let card = try #require(suggestions.current, "No idea on the card")
        suggestions.another()
        let inspiration = try #require(suggestions.current, "No second idea")

        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: profile, scriptLanguage: language.cue, interfaceLanguage: language.cue,
            preferredLanguages: [language.cue.rawValue]
        )
        let starts: [(source: String, idea: String, brief: IdeaBrief?, fromModel: Bool?)] = [
            ("card", FindInspirationViewModel.writingText(of: card), card.brief, card.angle != nil),
            ("findInspiration", FindInspirationViewModel.writingText(of: inspiration), inspiration.brief, inspiration.angle != nil),
            ("typed", language.typed, nil, nil),
        ]
        let consent = UltraConsentService(defaults: defaults.defaults)
        // Synthetic data only: this permission is the test's, in its own defaults; the creator's is untouched.
        consent.grant()
        let spend = UltraSpendLedger(defaults: defaults.defaults)
        let ultra = UltraScriptService(isAvailable: true, consent: consent, budget: UltraCallBudget(), spend: spend) { FirebaseUltraClient.make() }
        for start in starts {
            try #require(ultra.budget.allows(4), "The lab's calls are used up (\(ultra.budget.used) of \(ultra.budget.limit))")
            var request = factory.request(idea: start.idea, platform: .tiktok, format: nil, brief: start.brief)
            request.voice = Self.voice
            request.engine = .ultra
            let recorded = spend.entries.count
            let started = ContinuousClock.now
            var run: UltraRun?
            var failure: String?
            do {
                run = try await ultra.run(request)
            } catch {
                failure = "\(error)"
            }
            let seconds = started.duration(to: .now).inSeconds
            // The run's own record (a failed one is recorded too: what went out was spent).
            let cost = spend.entries.count > recorded ? spend.entries[spend.entries.count - 1].cost : UltraCost()
            let replies = [run?.draftReply, run?.checkReply, run?.reviewReply].compactMap(\.self)
            let text = run?.script.text ?? ""
            let sample = Sample(
                language: language.rawValue, source: start.source, idea: start.idea, ideaFromModel: start.fromModel, title: run?.script.title ?? "",
                script: text, words: ReadTime.wordCount(in: text), estimatedSeconds: ReadTime.seconds(for: text), calls: cost.calls,
                inputTokens: cost.inputTokens, cachedTokens: cost.cachedTokens, outputTokens: cost.outputTokens, thinkingTokens: cost.thinkingTokens,
                dollars: cost.dollars(), seconds: seconds,
                perCall: replies.map { [$0.promptTokens, $0.cachedTokens, $0.outputTokens, $0.thinkingTokens] }, failure: failure
            )
            print(String(
                format: "COST %@ %@: %d calls, in %d (cached %d), out %d, thinking %d, USD %.4f, %d words, ~%.0f s read, %.0f s to write%@",
                language.rawValue, start.source, cost.calls, cost.inputTokens, cost.cachedTokens, cost.outputTokens, cost.thinkingTokens,
                cost.dollars(), sample.words, sample.estimatedSeconds, seconds, failure.map { " · FAILED \($0)" } ?? ""
            ))
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            Attachment.record(try encoder.encode(sample), named: "ultra-cost-\(language.rawValue)-\(start.source).json")
            #expect(failure == nil, "\(start.source) failed: \(failure ?? "")")
        }
    }
}
