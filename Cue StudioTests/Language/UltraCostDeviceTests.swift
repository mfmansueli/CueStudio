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

/// What an Ultra AI script really costs, on the iPhone. Each script runs the app's flow (draft, check, polish, and the fit when it comes back
/// past its range) for a made-up finance and habits creator, and its cost is Google's own usage in each answer at `UltraPrice` (`UltraCost`),
/// printed as `COST …` lines and kept as attachments (`ultra-cost-<case>.json`). Synthetic data only, counted in the lab's calls.
///
/// - `threeStarts(_:)`, in each of the app's 20 script languages: the idea the card in Scripts suggests and the next one as Find inspiration
///   offers it ("Draft with Ultra AI"; Apple Intelligence writes them on this iPhone, as the app does, or the starters where it can't), and the
///   same typed idea in every language (planning the week in 20 minutes on Sunday), so the languages compare on one subject.
/// - `situation(_:)`, in Portuguese, English and Spanish: the other platforms and the lengths a creator chooses, no My Cue Voice, the two-step
///   flow, and a "Fit to time" the creator asks for on a long YouTube script.
///
/// `CUE_DEVICE="iago Lima iphone" scripts/test.sh device UltraCostDeviceTests` (`TEST_RUNNER_CUE_ULTRA_E2E=1`), the iPhone unlocked. The card's
/// ideas need the app in front, and the iPhone may sleep after one language: run one at a time with `TEST_RUNNER_CUE_ULTRA_COST_LANGUAGES=pt`
/// (`CueLanguage.interfaceLocalization` codes) and `TEST_RUNNER_CUE_ULTRA_COST_SITUATIONS=youtubeAuto,…` (`none` skips them).
@MainActor
@Suite("Ultra AI's cost on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_ULTRA_E2E"] != nil))
struct UltraCostDeviceTests {
    private static let languages = ProcessInfo.processInfo.environment["CUE_ULTRA_COST_LANGUAGES"]
        .map { Set($0.split(separator: ",").map(String.init)) }
    private static let situations = ProcessInfo.processInfo.environment["CUE_ULTRA_COST_SITUATIONS"]
        .map { Set($0.split(separator: ",").map(String.init)) }
    /// The languages the situations are measured in.
    private static let situationLanguages: [CueLanguage] = [.portugueseBrazil, .english, .spanish]

    /// What a creator changes from the dock's usual TikTok, Auto, with My Cue Voice and the three steps.
    nonisolated enum Situation: String, CaseIterable, Sendable {
        case youtubeAuto, youtube3Minutes, linkedinAuto, reels30Seconds, shorts1Minute, storiesAuto, noVoice, twoSteps

        var platform: Platform {
            switch self {
            case .youtubeAuto, .youtube3Minutes: .youtube
            case .linkedinAuto: .linkedin
            case .reels30Seconds: .reels
            case .shorts1Minute: .shorts
            case .storiesAuto: .stories
            case .noVoice, .twoSteps: .tiktok
            }
        }

        var length: ScriptLength {
            switch self {
            case .youtube3Minutes: .minutes3
            case .reels30Seconds: .seconds30
            case .shorts1Minute: .minute1
            default: .auto
            }
        }
    }

    private struct Sample: Encodable {
        let name: String
        let language: String
        let source: String
        let platform: String
        let length: String
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
        /// Each call's prompt, cached, output and thinking tokens, in order.
        let perCall: [[Int?]]
        let failure: String?
    }

    private struct Measured {
        let text: String
        let cost: UltraCost
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

    /// The same idea, typed in each language.
    private static let typedIdeas: [CueLanguage: String] = [
        .english: "How I plan my whole week in 20 minutes on Sunday, without any app",
        .spanish: "Cómo organizo toda la semana en 20 minutos el domingo, sin ninguna app",
        .portugueseBrazil: "Como eu organizo a semana inteira em 20 minutos no domingo, sem aplicativo nenhum",
        .french: "Comment j’organise toute ma semaine en 20 minutes le dimanche, sans aucune appli",
        .german: "Wie ich meine ganze Woche sonntags in 20 Minuten plane, ganz ohne App",
        .italian: "Come organizzo tutta la settimana in 20 minuti la domenica, senza nessuna app",
        .japanese: "日曜日の20分で、アプリを使わずに1週間の予定を立てる方法",
        .korean: "앱 없이 일요일 20분 만에 한 주 전체를 계획하는 방법",
        .chineseSimplified: "我如何在周日用20分钟规划好一整周，不用任何应用",
        .hindi: "मैं बिना किसी ऐप के रविवार को 20 मिनट में पूरे हफ़्ते की योजना कैसे बनाता हूँ",
        .indonesian: "Cara saya merencanakan seminggu penuh dalam 20 menit di hari Minggu, tanpa aplikasi apa pun",
        .arabic: "كيف أخطط لأسبوعي كله في 20 دقيقة يوم الأحد، دون أي تطبيق",
        .turkish: "Pazar günü 20 dakikada, hiçbir uygulama kullanmadan bütün haftamı nasıl planlıyorum",
        .thai: "วิธีวางแผนทั้งสัปดาห์ใน 20 นาทีในวันอาทิตย์ โดยไม่ใช้แอปใดๆ",
        .vietnamese: "Cách tôi lên kế hoạch cho cả tuần chỉ trong 20 phút vào Chủ nhật, không cần ứng dụng nào",
        .chineseTraditional: "我如何在週日用20分鐘規劃好一整週，不用任何應用程式",
        .dutch: "Hoe ik mijn hele week op zondag in 20 minuten plan, zonder app",
        .swedish: "Hur jag planerar hela veckan på 20 minuter på söndagen, utan någon app",
        .danish: "Hvordan jeg planlægger hele ugen på 20 minutter om søndagen, uden nogen app",
        .norwegian: "Hvordan jeg planlegger hele uka på 20 minutter på søndag, uten noen app",
    ]

    private static func typed(_ language: CueLanguage) -> String {
        typedIdeas[language] ?? "How I plan my whole week in 20 minutes on Sunday, without any app"
    }

    // MARK: - Cases

    @Test(.timeLimit(.minutes(5)), arguments: CueLanguage.allCases)
    func threeStarts(_ language: CueLanguage) async throws {
        guard Self.languages?.contains(language.interfaceLocalization) ?? true else { return }
        KeepScreenAwake.enable()
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = profile(defaults)

        // The card's ideas, as the app asks Apple Intelligence for them (the starters when it can't).
        let writer = ScriptAIService()
        let suggestions = IdeaSuggestionService(writer: writer, profile: profile, interfaceLanguage: { language }, defaults: defaults.defaults)
        if writer.availability.onDevice { await suggestions.refill() }
        let card = try #require(suggestions.current, "No idea on the card")
        suggestions.another()
        let inspiration = try #require(suggestions.current, "No second idea")

        let factory = factory(language, profile: profile)
        let ultra = try service(defaults)
        let code = language.interfaceLocalization
        for (source, idea) in [("card", card), ("findInspiration", inspiration)] {
            let text = FindInspirationViewModel.writingText(of: idea)
            try await measure(
                "\(code)-\(source)", language: code, source: source, idea: text, fromModel: idea.angle != nil,
                request: factory.request(idea: text, platform: .tiktok, format: nil, brief: idea.brief), ultra: ultra
            )
        }
        let typed = Self.typed(language)
        try await measure(
            "\(code)-typed", language: code, source: "typed", idea: typed, fromModel: nil,
            request: factory.request(idea: typed, platform: .tiktok, format: nil), ultra: ultra
        )
    }

    @Test(.timeLimit(.minutes(5)), arguments: Situation.allCases)
    func situation(_ situation: Situation) async throws {
        guard Self.situations?.contains(situation.rawValue) ?? true else { return }
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = profile(defaults)
        let ultra = try service(defaults)
        for language in Self.situationLanguages where Self.languages?.contains(language.interfaceLocalization) ?? true {
            let code = language.interfaceLocalization
            let idea = Self.typed(language)
            let request = factory(language, profile: profile).request(
                idea: idea, platform: situation.platform, format: nil, length: situation.length
            )
            let written = try await measure(
                "\(code)-\(situation.rawValue)", language: code, source: situation.rawValue, idea: idea, fromModel: nil, request: request,
                ultra: ultra, length: situation.length, voice: situation != .noVoice, flow: situation == .twoSteps ? .polished : .checked
            )
            // "Fit to time" asked for on a long YouTube script: one call, into TikTok's range.
            if situation == .youtubeAuto, let written, !written.text.isEmpty {
                try await measureFit("\(code)-fitToTime", language: language, script: written.text, ultra: ultra)
            }
        }
    }

    // MARK: - Measuring

    private func profile(_ defaults: TestDefaults) -> CreatorProfileService {
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile.niches = [.finance, .lifestyle]
        return profile
    }

    private func factory(_ language: CueLanguage, profile: CreatorProfileService) -> ScriptRequestFactory {
        ScriptRequestFactory(
            rules: TestData.rulesService(), profile: profile, scriptLanguage: language, interfaceLanguage: language,
            preferredLanguages: [language.rawValue]
        )
    }

    private func service(_ defaults: TestDefaults) throws -> UltraScriptService {
        try #require(UltraLabConfiguration.isPresent, "Copy the lab's configuration into the app's Documents first")
        let consent = UltraConsentService(defaults: defaults.defaults)
        // Synthetic data only: this permission is the test's, in its own defaults; the creator's is untouched.
        consent.grant()
        return UltraScriptService(
            isAvailable: true, consent: consent, budget: UltraCallBudget(), spend: UltraSpendLedger(defaults: defaults.defaults)
        ) { FirebaseUltraClient.make() }
    }

    /// One script, and what it cost (a failed one is recorded too: what went out was spent).
    @discardableResult
    private func measure(
        _ name: String, language: String, source: String, idea: String, fromModel: Bool?, request: ScriptRequest, ultra: UltraScriptService,
        length: ScriptLength = .auto, voice: Bool = true, flow: UltraFlow = .checked
    ) async throws -> Measured? {
        try #require(ultra.budget.allows(4), "The lab's calls are used up (\(ultra.budget.used) of \(ultra.budget.limit))")
        var request = request
        request.voice = voice ? Self.voice : nil
        request.engine = .ultra
        let recorded = ultra.spend?.entries.count ?? 0
        let started = ContinuousClock.now
        var run: UltraRun?
        var failure: String?
        do {
            run = try await ultra.run(request, flow: flow)
        } catch {
            failure = "\(error)"
        }
        let cost = lastCost(ultra, after: recorded)
        let replies = [run?.draftReply, run?.checkReply, run?.reviewReply].compactMap(\.self)
        let text = run?.script.text ?? ""
        record(Sample(
            name: name, language: language, source: source, platform: request.platform.rawValue, length: "\(length)", idea: idea,
            ideaFromModel: fromModel, title: run?.script.title ?? "", script: text, words: ReadTime.wordCount(in: text),
            estimatedSeconds: ReadTime.seconds(for: text), calls: cost.calls, inputTokens: cost.inputTokens, cachedTokens: cost.cachedTokens,
            outputTokens: cost.outputTokens, thinkingTokens: cost.thinkingTokens, dollars: cost.dollars(),
            seconds: started.duration(to: .now).inSeconds,
            perCall: replies.map { [$0.promptTokens, $0.cachedTokens, $0.outputTokens, $0.thinkingTokens] }, failure: failure
        ))
        return run.map { Measured(text: $0.script.text, cost: cost) }
    }

    private func measureFit(_ name: String, language: CueLanguage, script: String, ultra: UltraScriptService) async throws {
        try #require(ultra.budget.allows(1), "The lab's calls are used up")
        let recorded = ultra.spend?.entries.count ?? 0
        let started = ContinuousClock.now
        var fitted = ""
        var failure: String?
        do {
            fitted = try await ultra.fit(UltraFitRequest(
                script: script, platform: .tiktok, range: 75...105, voice: Self.voice, language: language.locale.language
            ))
        } catch {
            failure = "\(error)"
        }
        let cost = lastCost(ultra, after: recorded)
        record(Sample(
            name: name, language: language.interfaceLocalization, source: "fitToTime", platform: Platform.tiktok.rawValue, length: "75–105 s",
            idea: "\(ReadTime.wordCount(in: script)) words of YouTube", ideaFromModel: nil, title: "", script: fitted,
            words: ReadTime.wordCount(in: fitted), estimatedSeconds: ReadTime.seconds(for: fitted), calls: cost.calls,
            inputTokens: cost.inputTokens, cachedTokens: cost.cachedTokens, outputTokens: cost.outputTokens, thinkingTokens: cost.thinkingTokens,
            dollars: cost.dollars(), seconds: started.duration(to: .now).inSeconds, perCall: [], failure: failure
        ))
    }

    /// The cost of the request the ledger recorded after `count` entries; nothing when no call went out.
    private func lastCost(_ ultra: UltraScriptService, after count: Int) -> UltraCost {
        guard let spend = ultra.spend, spend.entries.count > count else { return UltraCost() }
        return spend.entries[spend.entries.count - 1].cost
    }

    private func record(_ sample: Sample) {
        print(String(
            format: "COST %@: %d calls, in %d (cached %d), out %d, thinking %d, USD %.4f, %d words, ~%.0f s read, %.0f s to write%@",
            sample.name, sample.calls, sample.inputTokens, sample.cachedTokens, sample.outputTokens, sample.thinkingTokens, sample.dollars,
            sample.words, sample.estimatedSeconds, sample.seconds, sample.failure.map { " · FAILED \($0)" } ?? ""
        ))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(sample) { Attachment.record(data, named: "ultra-cost-\(sample.name).json") }
        #expect(sample.failure == nil, "\(sample.name) failed: \(sample.failure ?? "")")
    }
}
