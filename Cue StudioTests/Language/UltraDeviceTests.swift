//
//  UltraDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Ultra AI for real on the iPhone, with synthetic data only (a made-up creator, never the owner's profile): the real Firebase client, the lab's
/// configuration and App Check token copied into the app's Documents, and the app's own call count (the 300 calls the owner authorized, kept in the
/// app's standard defaults, so these calls are counted with the ones made by hand). Each case is two calls (draft and polish); the five together
/// are ten.
///
/// - `scriptsDock`: an idea typed on the dock, Auto length (information, not a target), the synthetic voice.
/// - `findInspiration`: an idea from Find inspiration with its angle and opening line, one minute chosen.
/// - `length(_:)`: the same idea and voice under the three length conditions (free, about 90 s as a reference, 60–90 s required).
///
/// Every script is kept as an attachment (request, both calls' text and numbers, word count and estimated seconds at 150 words a minute, an
/// estimate, never a person reading it); `tools/ultra/collect.py` gathers them from the result bundle. The checks are the ones that don't judge
/// quality: something came back, in the asked language, and nothing private was in what was sent.
///
/// `CUE_DEVICE="iago Lima iphone" scripts/test.sh device UltraDeviceTests` (`TEST_RUNNER_CUE_ULTRA_E2E=1`), the iPhone unlocked;
/// `TEST_RUNNER_CUE_ULTRA_CASES=scriptsDock,findInspiration` narrows it.
@MainActor
@Suite("Ultra AI on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_ULTRA_E2E"] != nil))
struct UltraDeviceTests {
    private static let cases = ProcessInfo.processInfo.environment["CUE_ULTRA_CASES"].map { Set($0.split(separator: ",").map(String.init)) }
    private static let privateMarker = "SYNTHETIC-PRIVATE-SAMPLE"
    /// The same idea under the three length conditions.
    private static let lengthIdea = "Por que eu parei de olhar o celular na primeira hora do dia, e o que mudou nas minhas manhãs"

    nonisolated enum LengthCondition: String, CaseIterable, Sendable {
        case free, reference, required

        var length: UltraLength {
            switch self {
            case .free: .free
            case .reference: .reference(90)
            case .required: .required(60...90)
            }
        }
    }

    private struct Sample: Encodable {
        let name: String
        let language: String
        let durationPolicy: String
        let length: String
        let draftPrompt: String
        let reviewInstructionsCharacters: Int
        let draft: String
        let title: String
        let script: String
        let changes: [String]
        let draftSeconds: Double
        let reviewSeconds: Double
        let draftTokens: [Int?]
        let reviewTokens: [Int?]
        let modelVersion: String?
        let words: Int
        let estimatedSeconds: Double
        let callsUsed: Int
    }

    private static func enabled(_ name: String) -> Bool { cases?.contains(name) ?? true }

    /// A made-up creator: a pt-BR personal-finance and habits creator with every kind of preference, and writing samples that must never be sent.
    private static var voice: CreatorVoice {
        var voice = CreatorVoice(sounds: [.casual, .confident], phrases: ["Bora lá"], vocabulary: .simple, styles: [], niches: [.finance, .lifestyle])
        voice.role = .educator
        voice.audienceNote = "jovens adultos começando a organizar a rotina e o dinheiro"
        voice.style.sentences = .short
        voice.style.energy = .high
        voice.reach.length = .under30
        voice.endings = ["Ask a question to the audience"]
        voice.avoid = ["promessas de enriquecimento rápido"]
        voice.examples = [VoiceExample(text: "\(privateMarker) Meu jeito de abrir um vídeo é sempre com uma pergunta direta para quem assiste.")]
        voice.excerpts = [VoiceExcerpt(text: "\(privateMarker) Trecho importado de uma legenda antiga, longo o bastante para contar como trecho.")]
        voice.approvedSamples = [VoiceExample(text: "\(privateMarker) Um roteiro aprovado antes, que nunca deve sair do aparelho.")]
        return voice
    }

    private func factory(defaults: TestDefaults) -> ScriptRequestFactory {
        let languages = TestData.languages(defaults: defaults.defaults, systemLocalization: "pt", systemLanguages: ["pt-BR"])
        return ScriptRequestFactory(
            rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults), scriptLanguage: .portugueseBrazil,
            interfaceLanguage: languages.interfaceLanguage, preferredLanguages: languages.systemLanguages
        )
    }

    private func service(defaults: TestDefaults) throws -> UltraScriptService {
        try #require(UltraLabConfiguration.isPresent, "Copy the lab's configuration into the app's Documents first")
        let consent = UltraConsentService(defaults: defaults.defaults)
        // Synthetic data only: this permission is the test's, in its own defaults; the creator's is untouched.
        consent.grant()
        return UltraScriptService(isAvailable: true, consent: consent, budget: UltraCallBudget()) { FirebaseUltraClient.make() }
    }

    private func write(_ name: String, request: ScriptRequest, length: UltraLength? = nil, defaults: TestDefaults) async throws {
        let ultra = try service(defaults: defaults)
        try #require(ultra.budget.allows(ultra.flow.calls), "The lab's calls are used up (\(ultra.budget.used) of \(ultra.budget.limit))")
        let payload = UltraPayload(request, length: length)
        for text in [payload.draft.prompt, payload.review(of: "").prompt] { #expect(!text.contains(Self.privateMarker)) }
        let run = try await ultra.run(request, length: length)
        #expect(!run.script.text.isEmpty && run.script.engine == .ultra && run.script.needsFactCheck)
        let lengthName = switch payload.length {
        case .free: "free"
        case .reference(let seconds): "reference \(Int(seconds)) s"
        case .required(let range): "required \(Int(range.lowerBound))–\(Int(range.upperBound)) s"
        }
        let sample = Sample(
            name: name, language: request.language?.rawValue ?? "auto", durationPolicy: "\(request.durationPolicy)", length: lengthName,
            draftPrompt: payload.draft.prompt, reviewInstructionsCharacters: payload.review(of: run.draft).instructions.count, draft: run.draft,
            title: run.script.title, script: run.script.text, changes: run.changes, draftSeconds: run.draftSeconds, reviewSeconds: run.reviewSeconds,
            draftTokens: [run.draftReply.promptTokens, run.draftReply.outputTokens, run.draftReply.thinkingTokens],
            reviewTokens: [run.reviewReply.promptTokens, run.reviewReply.outputTokens, run.reviewReply.thinkingTokens],
            modelVersion: run.reviewReply.modelVersion ?? run.draftReply.modelVersion, words: ReadTime.wordCount(in: run.script.text),
            estimatedSeconds: ReadTime.seconds(for: run.script.text), callsUsed: ultra.budget.used
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        Attachment.record(try encoder.encode(sample), named: "ultra-sample-\(name).json")
    }

    @Test(.timeLimit(.minutes(5)))
    func scriptsDock() async throws {
        guard Self.enabled("scriptsDock") else { return }
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        var request = factory(defaults: defaults).request(
            idea: "3 erros que eu cometia ao montar meu primeiro orçamento mensal", platform: .tiktok, format: nil
        )
        request.voice = Self.voice
        request.engine = .ultra
        #expect(request.durationPolicy == .informative)
        try await write("scriptsDock", request: request, defaults: defaults)
    }

    @Test(.timeLimit(.minutes(5)))
    func findInspiration() async throws {
        guard Self.enabled("findInspiration") else { return }
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let brief = IdeaBrief(
            subject: "Por que guardar dinheiro parece mais difícil do que gastar",
            angle: "Explique um hábito pequeno que torna guardar dinheiro mais fácil.",
            openingLine: "Guardar dinheiro não é só força de vontade.", language: "pt", angleKind: "fact", topicKey: "finance"
        )
        // As Find inspiration sends it: the idea with its angle and opening line (`FindInspirationViewModel.writingText`), or the brief falls away.
        var request = factory(defaults: defaults).request(
            idea: brief.composerText, platform: .reels, format: nil, length: .minute1, brief: brief
        )
        request.voice = Self.voice
        request.engine = .ultra
        #expect(request.brief?.angle == brief.angle)
        try await write("findInspiration", request: request, defaults: defaults)
    }

    @Test(.timeLimit(.minutes(5)), arguments: LengthCondition.allCases)
    func length(_ condition: LengthCondition) async throws {
        guard Self.enabled(condition.rawValue) else { return }
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        var request = factory(defaults: defaults).request(idea: Self.lengthIdea, platform: .shorts, format: nil)
        request.voice = Self.voice
        request.engine = .ultra
        try await write("length-\(condition.rawValue)", request: request, length: condition.length, defaults: defaults)
    }
}
