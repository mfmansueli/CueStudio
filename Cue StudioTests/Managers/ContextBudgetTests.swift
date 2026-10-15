//
//  ContextBudgetTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The model's window shared out (`ContextBudget`): a request well inside goes as it is and is never counted; one near the edge loses the optional
/// parts of the voice first and keeps the language, the idea, its angle and the voice's rules.
@MainActor
@Suite("Context budget")
struct ContextBudgetTests {
    @Test func theFirstCandidateThatFitsIsTaken() async {
        let fitted = await ContextBudget.fitting([3_900, 3_000, 2_000], answer: 800, window: 4096) { $0 }
        #expect(fitted?.candidate == 3_000)
    }

    @Test func theSmallestIsTakenWhenNoneFits() async {
        let fitted = await ContextBudget.fitting([3_900, 3_800], answer: 800, window: 4096) { $0 }
        #expect(fitted?.candidate == 3_800)
    }

    @Test func aCountThatCantBeHadEndsTheSearch() async {
        let fitted = await ContextBudget.fitting([3_900, 1_000], answer: 800, window: 4096) { _ in nil }
        #expect(fitted?.candidate == 3_900 && fitted?.tokens == nil)
    }

    @Test func anEstimateWellInsideIsNotCounted() {
        let budget = ContextBudget(window: 4096)
        #expect(budget.isClearlyInside(estimate: 1_300, answer: 800))
        #expect(!budget.isClearlyInside(estimate: 2_400, answer: 800))
    }

    // MARK: - A script request

    private func request(language: CueLanguage = .japanese) -> ScriptRequest {
        let brief = IdeaBrief(subject: "朝のストレッチ", angle: "腰と肩のための五分間のウォームアップを見せる。", openingLine: "最初のスクワットの前に始まります。")
        var profile = QualityProfiles.english.full
        profile.examples = [VoiceExample(text: String(repeating: "朝は水を一杯飲んでから、五分だけ体を動かします。", count: 6))]
        let voice = profile.voice(inLanguage: "ja")
        return ScriptRequest(
            source: .prompt(brief.composerText), platform: .youtube, tone: nil, voice: voice, targetRange: 240...300, language: language, brief: brief
        )
    }

    @Test func aRequestWellInsideTheWindowGoesAsItIs() async {
        let service = ScriptAIService(capabilities: FakeAIModelCapabilities(), measure: FakePromptMeasure())
        var small = request(language: .english)
        small.targetRange = 30...45
        let fitted = await service.fitted(small, on: .onDevice)
        #expect(fitted.voiceBudget == nil)
    }

    @Test func aRequestOverTheWindowLosesTheExamplesFirstAndKeepsWhatMatters() async {
        // A script the estimate underrates threefold (Japanese, measured at 0.52 tokens a character against 0.3 estimated, with room to spare).
        let service = ScriptAIService(capabilities: FakeAIModelCapabilities(), measure: FakePromptMeasure(factor: 3))
        let full = request()
        let fitted = await service.fitted(full, on: .onDevice)
        #expect(fitted.voiceBudget != nil, "the voice was cut to fit")
        let before = ScriptPromptBuilder.instructions(for: full)
        let after = ScriptPromptBuilder.instructions(for: fitted)
        #expect(before.contains("Here is how they write") && !after.contains("Here is how they write"), "the examples go first")
        for kept in ["Japanese", "They speak as one person", "Rules:", "Okay, real talk."] {
            #expect(after.contains(kept), "\(kept) is kept")
        }
        let prompt = ScriptPromptBuilder.prompt(for: fitted)
        #expect(prompt.contains(full.brief?.angle ?? "-") && prompt.contains(full.brief?.openingLine ?? "-"), "the angle and the opening line are kept")
    }

    @Test func anotherRouteIsNotCounted() async {
        let service = ScriptAIService(capabilities: FakeAIModelCapabilities(), measure: FakePromptMeasure(factor: 3))
        #expect(await service.fitted(request(), on: .privateCloud).voiceBudget == nil)
    }
}
