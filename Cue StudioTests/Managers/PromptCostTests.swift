//
//  PromptCostTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The cost of a text to the model is an estimate, so it is held to what the model was measured to charge: the same four sentences in each of the
/// 20 languages of the app, counted by the on-device model on an iPhone 15 Pro (`PromptBudgetDeviceTests`, 7 Oct 2026).
@Suite("Prompt cost")
struct PromptCostTests {
    /// Tokens the model counted for `sample(in:)` in each language.
    private static let measured: [(language: String, tokens: Int)] = [
        ("ar", 65), ("da", 69), ("de", 71), ("en", 50), ("es", 59), ("fr", 61), ("hi", 60), ("id", 59), ("it", 64), ("ja", 55),
        ("ko", 68), ("nb", 67), ("nl", 74), ("pt-BR", 60), ("sv", 68), ("th", 61), ("tr", 63), ("vi", 64), ("zh-Hans", 55), ("zh-Hant", 58),
    ]

    private static let sentences = [
        "Mornings can be challenging, but there are good habits that can help you start the day.",
        "Consider limiting phone use, drinking water and setting goals for the day.",
        "Three small habits changed how my mornings feel.",
        "Save this for tomorrow morning.",
    ]

    private static func sample(in language: String) -> String {
        let bundle = Bundle(for: ScriptAIService.self)
        guard language != "en", let path = bundle.path(forResource: language, ofType: "lproj"), let localized = Bundle(path: path) else {
            return sentences.joined(separator: " ")
        }
        return sentences.map { localized.localizedString(forKey: $0, value: $0, table: nil) }.joined(separator: " ")
    }

    @Test(arguments: measured)
    func theEstimateIsNeverFarBelowWhatTheModelCharged(language: String, tokens: Int) {
        let estimate = PromptCost.tokens(of: Self.sample(in: language))
        // Under-estimating is what overflows the window: the estimate may be a good deal above the measure, never much below it.
        #expect(Double(estimate) >= Double(tokens) * 0.85, "\(language): estimated \(estimate), the model charged \(tokens)")
        #expect(Double(estimate) <= Double(tokens) * 1.7, "\(language): estimated \(estimate), the model charged \(tokens): the budget would be wasted")
    }

    @Test func englishCostsItsCharacters() {
        #expect(PromptCost.units(of: "Okay, real talk about “mornings” — it works.") == "Okay, real talk about “mornings” — it works.".count)
    }

    @Test func aScriptThatTakesMoreTokensCostsMore() {
        let english = "Three small habits changed how my mornings feel."
        let chinese = "三个小习惯改变了我早晨的感觉。"
        #expect(PromptCost.units(of: chinese) / chinese.count >= 2)
        #expect(PromptCost.units(of: chinese) > chinese.count && PromptCost.units(of: english) == english.count)
    }

    @Test func aTextIsShortenedAtAWordToWhatItMayCost() {
        let text = String(repeating: "Okay real talk mornings are hard. ", count: 12)
        let short = PromptCost.shortened(text, toUnits: 120)
        #expect(PromptCost.units(of: short) <= 120 && short.hasSuffix("…") && !short.contains("  "))
        #expect(PromptCost.shortened("Short.", toUnits: 120) == "Short.")
    }

    @Test func aChineseExampleIsShortenedToTheSameCostAsAnEnglishOne() {
        let chinese = String(repeating: "三个小习惯改变了我早晨的感觉。", count: 20)
        let short = PromptCost.shortened(chinese, toUnits: 200)
        #expect(PromptCost.units(of: short) <= 200 && short.count < 100)
    }
}
