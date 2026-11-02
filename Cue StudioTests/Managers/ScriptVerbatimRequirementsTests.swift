//
//  ScriptVerbatimRequirementsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Explicit verbatim requirements")
struct ScriptVerbatimRequirementsTests {
    @Test(arguments: [
        "Include exactly", "Inclua exatamente", "Incluye exactamente", "Écris exactement", "Schreibe wörtlich",
        "Scrivi esattamente", "次をそのまま", "다음을 그대로", "原样写", "हूबहू लिखें", "Tulis persis",
        "اكتب حرفيا", "Aynen yaz", "เขียนตามนี้", "Viết nguyên văn", "原樣寫", "Schrijf letterlijk",
        "Skriv ordagrant", "Skriv ordret", "Skriv ordrett",
    ])
    func explicitFormsAcrossTheTwentyLanguagesPreserveTheOriginalCharacters(_ directive: String) {
        #expect(ScriptVerbatimRequirements.phrases(in: .prompt("\(directive): Keep THIS, exactly.")) == ["Keep THIS, exactly."])
    }

    @Test func quotedTextCanBeFollowedByOtherInstructions() {
        let text = "Explain planning. Include exactly: “Less rush, more intention.” Then end without a CTA."
        #expect(ScriptVerbatimRequirements.phrases(in: .prompt(text)) == ["Less rush, more intention."])
    }

    @Test func aDifferentNameOrNumberCannotPassAsTheRequestedText() {
        #expect(!ScriptVerbatimRequirements.contains("Aurora27", in: "Aurora270"))
        #expect(!ScriptVerbatimRequirements.contains("14:35", in: "214:35"))
        #expect(ScriptVerbatimRequirements.contains("Aurora27", in: "Aurora27は明日です。"))
        #expect(ScriptVerbatimRequirements.contains("Café", in: "Cafe\u{301}"))
        #expect(!ScriptVerbatimRequirements.contains("Keep THIS.", in: "Keep this."))
    }

    @Test func negatedOrAmbiguousDirectionsAreNotInventedRequirements() {
        for text in [
            "Do not include exactly: Hello.", "Não diga exatamente: Olá.", "No incluye exactamente: Hola.",
            "不要原样写：你好。", "อย่าเขียนตามนี้: Hello.",
            "Include exactly three examples.", "Include exactly: Hello. Then explain this.", "Include exactly: Hello. Then explain this",
        ] {
            #expect(ScriptVerbatimRequirements.phrases(in: .prompt(text)).isEmpty, "\(text)")
        }
    }

    @Test func anAbsentRequiredPhraseTriggersOneBoundedCorrectionEvenWithoutMyCueVoice() async throws {
        let request = ScriptRequest(
            source: .prompt("Explain planning and include exactly: Less rush, more intention."), platform: .reels,
            voice: nil, targetRange: 15...30, language: .english
        )
        var attempts = 0
        let base = "I choose one idea, outline a few points and decide what viewers should learn before recording."
        let writer = VoiceCheckedWriting(draft: { _, violations in
            attempts += 1
            if attempts == 2 { #expect(violations.contains { $0.kind == .requiredPhrase }) }
            return GeneratedScript(title: "Planning", text: attempts == 1 ? base : base + " Less rush, more intention.", usedLanguageModel: true)
        }, isGuardrailRefusal: { _ in false }, report: { _, _ in })
        let result = try await writer.write(request)
        #expect(attempts == 2)
        #expect(result.text.contains("Less rush, more intention."))
        #expect(!result.voiceViolations.contains(.requiredPhrase))
        #expect(request.preservedPhrases.contains("Less rush, more intention."))
    }

    @Test func aFailedCorrectionDoesNotDeliverChangedRequiredWording() async {
        let request = ScriptRequest(source: .prompt("Include exactly: Keep this sentence."), platform: .reels,
                                    voice: nil, targetRange: 15...30, language: .english)
        var attempts = 0
        let writer = VoiceCheckedWriting(draft: { _, _ in
            attempts += 1
            return GeneratedScript(title: "Draft", text: "I keep a sentence with different words.", usedLanguageModel: true)
        }, isGuardrailRefusal: { _ in false }, report: { _, _ in })
        await #expect(throws: ScriptAIError.self) { try await writer.write(request) }
        #expect(attempts == 2)
    }
}
