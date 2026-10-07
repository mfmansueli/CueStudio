//
//  PromptBudgetDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// What the 1200 characters of voice cost the model on a real iPhone, and what it would cost to send more: the tokens a text takes in each of
/// the 20 languages (the same characters are far more tokens in Japanese or Thai than in English), the tokens of a whole request at a few sizes
/// of voice, and how long the model takes to start answering at each. The numbers go to the console and to an attachment; they decide the budget
/// (`VoiceBrief.budget`), they don't assert one.
///
/// Opt-in and on a device with Apple Intelligence on, unlocked and awake: `CUE_DEVICE=<iPhone> scripts/test.sh device PromptBudgetDeviceTests`.
@MainActor
@Suite("Prompt budget on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct PromptBudgetDeviceTests {
    private static let sentences = [
        "Mornings can be challenging, but there are good habits that can help you start the day.",
        "Consider limiting phone use, drinking water and setting goals for the day.",
        "Three small habits changed how my mornings feel.",
        "Save this for tomorrow morning.",
    ]

    private func model() throws -> SystemLanguageModel {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { try Test.cancel("Apple Intelligence isn't available on this device") }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        return model
    }

    /// The same four sentences as the app says them in `code`, from the app's own String Catalog.
    private func text(in code: String) -> String {
        let bundle = Bundle(for: ScriptAIService.self)
        guard let path = bundle.path(forResource: code, ofType: "lproj"), let localized = Bundle(path: path) else {
            return Self.sentences.joined(separator: " ")
        }
        return Self.sentences.map { localized.localizedString(forKey: $0, value: $0, table: nil) }.joined(separator: " ")
    }

    /// The folder of a language in the app: "pt-BR" and the two Chinese scripts keep their region or script, the rest are the language alone.
    private static func catalogCode(of language: CueLanguage) -> String {
        switch language {
        case .portugueseBrazil: "pt-BR"
        case .chineseSimplified: "zh-Hans"
        case .chineseTraditional: "zh-Hant"
        default: language.rawValue.split(separator: "-").first.map(String.init) ?? language.rawValue
        }
    }

    @Test func tokensPerCharacterInEveryLanguage() async throws {
        KeepScreenAwake.enable()
        let model = try model()
        var lines = ["CONTEXT SIZE \(model.contextSize) tokens"]
        for language in CueLanguage.allCases {
            let sample = text(in: Self.catalogCode(of: language))
            let tokens = try await model.tokenCount(for: sample)
            let ratio = Double(tokens) / Double(max(1, sample.count))
            lines.append(String(format: "TOKENS %@ chars=%d tokens=%d tokens/char=%.3f", language.rawValue, sample.count, tokens, ratio))
        }
        lines.forEach { print($0) }
        Attachment.record(Data(lines.joined(separator: "\n").utf8), named: "token-cost-by-language.txt")
        #expect(model.contextSize > 0)
    }

    /// A voice with everything a creator can say, so that a larger budget has something to send.
    private func fullProfile() -> CreatorProfile {
        let persona = VoicePersonas.all[0]
        var profile = persona.profile
        let analysis = WritingAnalyzer.analyze(WritingSamples.maya.map { WritingPiece(text: $0) })
        profile.excerpts = analysis.excerpts
        profile.fingerprint = analysis.fingerprint
        profile.examples = analysis.excerpts.prefix(3).map { VoiceExample(text: $0.text) }
        return profile
    }

    @Test func whatTheBudgetCostsInTokensAndTime() async throws {
        KeepScreenAwake.enable()
        let model = try model()
        let persona = VoicePersonas.all[0]
        let idea = persona.ideas[0]
        let original = VoiceBrief.budget
        defer { VoiceBrief.budget = original }
        var lines: [String] = []
        for budget in [0, 1200, 1500, 1800, 2400] {
            VoiceBrief.budget = max(budget, 1)
            let request = persona.request(for: idea, withVoice: budget > 0, profile: fullProfile())
            let instructions = ScriptPromptBuilder.instructions(for: request)
            let prompt = ScriptPromptBuilder.prompt(for: request)
            let briefLength = request.voice.map { VoiceBriefBuilder.brief(for: $0).length } ?? 0
            let tokens = try await model.tokenCount(for: Instructions(instructions)) + model.tokenCount(for: prompt)
            var firsts: [Double] = []
            for _ in 0..<3 {
                let session = LanguageModelSession(model: model, instructions: instructions)
                let started = ContinuousClock.now
                _ = try await session.respond(to: prompt, options: GenerationOptions(maximumResponseTokens: 1))
                firsts.append(started.duration(to: .now).inSeconds)
                try await Task.sleep(for: .seconds(3))
            }
            lines.append(String(
                format: "BUDGET %d brief=%d chars request=%d tokens first-token=%.2f/%.2f/%.2f s",
                budget, briefLength, tokens, firsts[0], firsts[1], firsts[2]
            ))
            print(lines.last ?? "")
        }
        Attachment.record(Data(lines.joined(separator: "\n").utf8), named: "budget-cost.txt")
        #expect(lines.count == 5)
    }
}
