//
//  UltraQualityDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// The comparison Codex's lab report left for next (`reports/FIREBASE_SCRIPT_QUALITY_2026-10-29.md`): the same ideas, from the same request the
/// app builds, written by Apple Intelligence (the app's writer, `ScriptAIService()`), by Ultra AI as it is (draft and polish) and by Ultra AI with
/// the claims checked on their own (`UltraFlow.checked`). The ideas are the quality creators Apple Intelligence is measured with
/// (`QualityProfiles`, My Cue Voice in full: English, Brazilian Portuguese, Spanish) and six Portuguese subjects where a script easily gets a
/// technical claim wrong (light, cameras, the teleprompter, sound, an emergency fund, sleep). Synthetic creators only.
///
/// Every idea is kept as one attachment with all three scripts, the Ultra drafts, the check's corrections and the editor's changes, and what the
/// polish was told; `tools/ultra/compare.py` gathers them, measures what a rule can, and deals blind pairs for the owner and a judge. Nothing
/// here judges quality: it checks that each engine either wrote or said why not.
///
/// `CUE_DEVICE="iago Lima iphone" TEST_RUNNER_CUE_ULTRA_QUALITY_RUN=q1 scripts/test.sh device UltraQualityDeviceTests`, the iPhone unlocked and
/// awake (Apple Intelligence is rate limited in the background). `TEST_RUNNER_CUE_ULTRA_QUALITY_CASES=t1-window-light,en-0` and
/// `TEST_RUNNER_CUE_ULTRA_QUALITY_ENGINES=apple,checked` narrow it. Each idea costs 14 of the lab's calls (2 + 3, and 3 for each cheaper
/// variant of the checked flow that thinks less, `checkedMedium`, `checkedLow` and `checkedMixed`: `UltraThinking`).
///
/// `TEST_RUNNER_CUE_ULTRA_QUALITY_FIT=1` runs the other half instead, with no call to Google: the owner's choice (29/10/2026) is that Ultra writes
/// freely and the creator fits it to the platform's time when they want, with the page's "Fit to time" (Apple Intelligence, on the iPhone). It
/// fits the checked scripts of run q1 (`Fixtures/UltraScripts`) exactly as the script page does, for `tools/ultra/compare.py` to show what was
/// cut and kept.
@MainActor
@Suite("Ultra AI against Apple Intelligence", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_ULTRA_QUALITY"] != nil))
struct UltraQualityDeviceTests {
    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let id: String
        /// "technical" (a subject with claims to get right) or "profile" (a quality creator's idea).
        let kind: String
        let language: CueLanguage
        let creator: CreatorProfile
        let idea: String
        var brief: IdeaBrief?
        var length: ScriptLength = .auto
        var testDescription: String { id }
    }

    nonisolated enum Engine: String, CaseIterable, Sendable {
        case apple, polished, checked
        /// The app's flow thinking less (`UltraThinking`): in every call, or in all but the claim check (`checkedMixed`). What a cheaper script
        /// would write.
        case checkedMedium, checkedLow, checkedMixed

        var flow: UltraFlow { self == .polished ? .polished : .checked }

        var thinking: UltraThinking {
            switch self {
            case .checkedMedium: .medium
            case .checkedLow: .low
            case .checkedMixed: .lowExceptCheck
            default: .model
            }
        }
    }

    private static let environment = ProcessInfo.processInfo.environment
    private static let run = environment["CUE_ULTRA_QUALITY_RUN"] ?? "run"
    private static let engines: [Engine] = environment["CUE_ULTRA_QUALITY_ENGINES"].map {
        $0.split(separator: ",").compactMap { Engine(rawValue: String($0)) }
    } ?? Engine.allCases

    nonisolated static let cases: [Case] = {
        let wanted = ProcessInfo.processInfo.environment["CUE_ULTRA_QUALITY_CASES"].map { Set($0.split(separator: ",").map(String.init)) }
        return (technical + profiles).filter { wanted?.contains($0.id) ?? true }
    }()

    // MARK: - Ideas

    /// A Brazilian creator who teaches small creators to film with a phone at home. No usual ending: a call to comment would be a habit.
    nonisolated private static let filming = CreatorProfile(
        niches: [.education, .tech], customTopics: ["Gravar vídeos com o celular"], phrases: ["Simbora"], role: .educator,
        sounds: [.casual, .confident], confirmedVoiceSteps: [.audience, .tone], formats: [.tutorial],
        style: VoiceDelivery(energy: .balanced, sentences: .short, words: .plain, swearing: .never), avoid: ["Promessas exageradas"],
        audienceNote: "criadores pequenos que gravam com o celular em casa, sem equipe", speaksAs: .i
    )

    /// A Brazilian creator on money and habits for young adults. No usual ending either.
    nonisolated private static let money = CreatorProfile(
        niches: [.finance, .lifestyle], phrases: ["Bora lá"], role: .educator, sounds: [.casual, .confident],
        confirmedVoiceSteps: [.audience, .tone], style: VoiceDelivery(energy: .high, sentences: .short, words: .plain),
        avoid: ["Promessas de enriquecimento rápido"], audienceNote: "jovens adultos começando a organizar a rotina e o dinheiro", speaksAs: .i
    )

    nonisolated private static let technical: [Case] = [
        Case(id: "t1-window-light", kind: "technical", language: .portugueseBrazil, creator: filming,
             idea: "Como usar a luz da janela para gravar sem estourar o rosto", length: .minute1),
        Case(id: "t2-camera-upgrade", kind: "technical", language: .portugueseBrazil, creator: filming,
             idea: "Vale a pena trocar o celular por uma câmera para gravar vídeos?"),
        Case(id: "t3-teleprompter", kind: "technical", language: .portugueseBrazil, creator: filming,
             idea: "Como ler o roteiro no teleprompter sem parecer um robô"),
        Case(id: "t4-sound", kind: "technical", language: .portugueseBrazil, creator: filming,
             idea: "Por que o som importa mais do que a imagem nos seus vídeos"),
        Case(id: "t5-emergency-fund", kind: "technical", language: .portugueseBrazil, creator: money,
             idea: "Reserva de emergência: quanto guardar e onde deixar o dinheiro", length: .minute1),
        Case(id: "t6-sleep-spending", kind: "technical", language: .portugueseBrazil, creator: money,
             idea: "Por que dormir mal faz você gastar mais no dia seguinte"),
    ]

    /// The quality creators' two free ideas and their Find inspiration brief, as Apple Intelligence's measurement writes them.
    nonisolated private static let profiles: [Case] = QualityProfiles.all.flatMap { profile in
        profile.cases.enumerated().map { index, entry in
            Case(
                id: "\(profile.language.rawValue)-\(index)", kind: "profile", language: profile.language, creator: profile.profile(.full),
                idea: entry.idea, brief: entry.brief
            )
        }
    }

    // MARK: - Writing

    /// "apple" (the page's Fit to time today) or "ultra" (`UltraScriptService.fit`, one call a script); any other value is "apple".
    nonisolated private static let fits = ProcessInfo.processInfo.environment["CUE_ULTRA_QUALITY_FIT"] != nil
    nonisolated private static let fitsWithUltra = ProcessInfo.processInfo.environment["CUE_ULTRA_QUALITY_FIT"] == "ultra"

    private final class BundleToken {}

    @Test(.timeLimit(.minutes(5)), .enabled(if: !fits), arguments: UltraQualityDeviceTests.cases)
    func writesTheIdea(_ item: Case) async throws {
        KeepScreenAwake.enable()
        #if canImport(UIKit)
        try #require(UIApplication.shared.applicationState == .active, "The iPhone must be unlocked with the screen on")
        #endif
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let request = Self.request(item)
        var ultraRequest = request
        ultraRequest.engine = .ultra
        let ultra = try ultraService(defaults: defaults)
        var sample = Sample(item: item, request: request, run: Self.run)
        sample.context = UltraPayload(ultraRequest).review(of: "[draft]").prompt
        for engine in Self.engines {
            switch engine {
            case .apple: sample.engines[engine.rawValue] = await Self.apple(request)
            case .polished, .checked, .checkedMedium, .checkedLow, .checkedMixed:
                try #require(ultra.budget.allows(engine.flow.calls), "The lab's calls are used up (\(ultra.budget.used) of \(ultra.budget.limit))")
                ultra.thinking = engine.thinking
                sample.engines[engine.rawValue] = await Self.ultra(ultraRequest, flow: engine.flow, service: ultra)
            }
            try await Task.sleep(for: .seconds(2))
        }
        sample.callsUsed = ultra.budget.used
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        Attachment.record(try encoder.encode(sample), named: "ultra-quality-\(Self.run)-\(item.id).json")
        #expect(sample.engines.values.allSatisfy { $0.text != nil || $0.failure != nil })
    }

    // MARK: - Fitting

    /// "Fit to time" on an Ultra script: the creator's platform range (TikTok, with their monetization goals) and their voice, by Apple
    /// Intelligence as the script page runs it (a rate limit is waited out twice) or by Ultra (`TEST_RUNNER_CUE_ULTRA_QUALITY_FIT=ultra`, one of
    /// the lab's calls for each script outside the range).
    @Test(.timeLimit(.minutes(5)), .enabled(if: fits), arguments: UltraQualityDeviceTests.cases)
    func fitsTheUltraScript(_ item: Case) async throws {
        KeepScreenAwake.enable()
        #if canImport(UIKit)
        try #require(UIApplication.shared.applicationState == .active, "The iPhone must be unlocked with the screen on")
        #endif
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "ultra-checked-q1", withExtension: "json"))
        let scripts = try JSONDecoder().decode([String: [String: String]].self, from: Data(contentsOf: url))
        guard let text = scripts[item.id]?["text"] else { try Test.cancel("No Ultra script for \(item.id)") }
        let language = item.language.locale.language
        let range = TestData.rulesService().preset(for: .tiktok, monetizationGoals: item.creator.monetizationGoals).idealRange
        let context = RewriteContext(
            structure: .generic, platform: .tiktok, idealRange: range, sourceLanguage: language,
            voice: item.creator.voice(inLanguage: language.languageCode?.identifier, idea: text)
        )
        var fitted = Fitted(id: item.id, range: [range.lowerBound, range.upperBound], before: text)
        let started = ContinuousClock.now
        if Self.fitsWithUltra {
            let defaults = TestDefaults()
            defer { defaults.tearDown() }
            let ultra = try ultraService(defaults: defaults)
            try #require(ultra.budget.allows(1), "The lab's calls are used up (\(ultra.budget.used) of \(ultra.budget.limit))")
            do {
                fitted.after = try await ultra.fit(UltraFitRequest(
                    script: text, platform: .tiktok, range: range, voice: context.voice, language: language
                ))
            } catch {
                fitted.failure = "\(error)"
            }
            fitted.engine = "ultra"
        } else {
            try await Self.appleFit(text, context: context, into: &fitted)
        }
        fitted.seconds = started.duration(to: .now).inSeconds
        fitted.wordsAfter = fitted.after.map { ReadTime.wordCount(in: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        Attachment.record(try encoder.encode(fitted), named: "ultra-fit-\(Self.run)-\(item.id).json")
        #expect(fitted.after != nil || fitted.failure != nil)
    }

    private static func appleFit(_ text: String, context: RewriteContext, into fitted: inout Fitted) async throws {
        let service = ScriptAIService()
        guard service.availability.onDevice else { try Test.cancel("Apple Intelligence isn't available on this device") }
        for attempt in 1...3 {
            do {
                let result = try await service.rewriteReported(text, with: .fitToTime, context: context)
                fitted.after = result.text
                fitted.parts = [result.parts, result.leftAsWritten]
                break
            } catch ScriptAIError.rateLimited where attempt < 3 {
                try? await Task.sleep(for: .seconds(30))
            } catch {
                fitted.failure = "\(error)"
                break
            }
        }
        fitted.engine = "apple"
    }

    private struct Fitted: Encodable {
        let id: String
        let range: [Double]
        let before: String
        let wordsBefore: Int
        var engine = ""
        var after: String?
        var wordsAfter: Int?
        /// The parts the script was fitted in, and how many of them were left as they were.
        var parts: [Int]?
        var failure: String?
        var seconds: Double?

        init(id: String, range: [Double], before: String) {
            self.id = id
            self.range = range
            self.before = before
            wordsBefore = ReadTime.wordCount(in: before)
        }
    }

    /// The request the dock sends for the idea, built by the factory the app uses, the interface in the creator's language.
    private static func request(_ item: Case) -> ScriptRequest {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile = item.creator
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: profile, scriptLanguage: nil, interfaceLanguage: item.language,
            preferredLanguages: [item.language.rawValue]
        )
        return factory.request(idea: item.idea, platform: .tiktok, format: nil, length: item.length, brief: item.brief)
    }

    private func ultraService(defaults: TestDefaults) throws -> UltraScriptService {
        try #require(UltraLabConfiguration.isPresent, "Copy the lab's configuration into the app's Documents first")
        let consent = UltraConsentService(defaults: defaults.defaults)
        // Synthetic data only: this permission is the test's, in its own defaults; the creator's is untouched.
        consent.grant()
        return UltraScriptService(isAvailable: true, consent: consent, budget: UltraCallBudget()) { FirebaseUltraClient.make() }
    }

    /// Apple Intelligence as the app writes with it; a rate limit (the model's, in bursts) is waited out twice.
    private static func apple(_ request: ScriptRequest) async -> Written {
        let service = ScriptAIService()
        let started = ContinuousClock.now
        for attempt in 1...3 {
            do {
                let script = try await service.generate(request)
                var result = Written(title: script.title, text: script.text)
                result.model = script.model?.rawValue
                result.seconds = ["total": started.duration(to: .now).inSeconds]
                return result
            } catch ScriptAIError.rateLimited where attempt < 3 {
                try? await Task.sleep(for: .seconds(30))
            } catch {
                return Written(failure: "\(error)")
            }
        }
        return Written(failure: "rate limited")
    }

    private static func ultra(_ request: ScriptRequest, flow: UltraFlow, service: UltraScriptService) async -> Written {
        do {
            let run = try await service.run(request, flow: flow)
            var result = Written(title: run.script.title, text: run.script.text)
            result.draft = run.draft
            result.checked = run.checked
            result.corrections = run.corrections
            result.changes = run.changes
            result.model = run.reviewReply.modelVersion ?? run.draftReply.modelVersion
            result.seconds = ["draft": run.draftSeconds, "review": run.reviewSeconds]
            result.seconds?["check"] = run.checkSeconds
            result.tokens = ["draft": Self.tokens(run.draftReply), "review": Self.tokens(run.reviewReply)]
            if let reply = run.checkReply { result.tokens?["check"] = Self.tokens(reply) }
            result.calls = run.cost.calls
            result.usd = run.cost.dollars()
            return result
        } catch {
            return Written(failure: "\(error)")
        }
    }

    private static func tokens(_ reply: UltraModelReply) -> [Int?] {
        [reply.promptTokens, reply.outputTokens, reply.thinkingTokens]
    }

    // MARK: - Record

    private struct Sample: Encodable {
        let run: String
        let id: String
        let kind: String
        let language: String
        let platform: String
        let idea: String
        let brief: [String: String]?
        let durationPolicy: String
        let lengthAsked: String
        let creator: Creator
        var context = ""
        var engines: [String: Written] = [:]
        var callsUsed = 0

        init(item: Case, request: ScriptRequest, run: String) {
            self.run = run
            id = item.id
            kind = item.kind
            language = item.language.rawValue
            platform = request.platform.promptName
            idea = item.idea
            brief = item.brief.map { ["subject": $0.subject, "angle": $0.angle, "openingLine": $0.openingLine] }
            durationPolicy = "\(request.durationPolicy)"
            lengthAsked = switch UltraLength(request) {
            case .free: "free"
            case .reference(let seconds): "reference \(Int(seconds)) s"
            case .required(let range): "required \(Int(range.lowerBound))–\(Int(range.upperBound)) s"
            case .ideal(let range): "ideal \(Int(range.lowerBound))–\(Int(range.upperBound)) s"
            }
            creator = Creator(item.creator)
        }
    }

    private struct Creator: Encodable {
        let summary: String
        let phrases: [String]
        let openings: [String]
        let endings: [String]

        init(_ profile: CreatorProfile) {
            let parts = [
                "niches: " + (profile.niches.map(\.rawValue) + profile.customTopics).joined(separator: ", "),
                "sounds: " + profile.sounds.map(\.rawValue).joined(separator: ", "),
                profile.role.map { "role: \($0.rawValue)" },
                profile.audienceNote.map { "audience: \($0)" },
                profile.avoid.isEmpty ? nil : "avoid: " + profile.avoid.joined(separator: ", "),
            ]
            summary = parts.compactMap(\.self).joined(separator: " · ")
            phrases = profile.phrases
            openings = profile.openings
            endings = profile.endings
        }
    }

    private struct Written: Encodable {
        var title: String?
        var text: String?
        var failure: String?
        var model: String?
        var draft: String?
        var checked: String?
        var corrections: [String]?
        var changes: [String]?
        var seconds: [String: Double]?
        var tokens: [String: [Int?]]?
        /// Every call of the script and what they cost (`UltraCost`), the fit that follows a script past its range included.
        var calls: Int?
        var usd: Double?
        var words: Int?
        var estimatedSeconds: Double?

        init(title: String, text: String) {
            self.title = title
            self.text = text
            words = ReadTime.wordCount(in: text)
            estimatedSeconds = ReadTime.seconds(for: text)
        }

        init(failure: String) {
            self.failure = failure
        }
    }
}
