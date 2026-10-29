//
//  TextToSpeechViewModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Text to speech's sheet: it starts in the take's language with the best voice there (or the nearest language this iPhone
/// speaks), says when only compact voices exist, keeps the text under its limit, starts from the narration being changed, hands
/// the made narration over, and a cancel adds nothing.
@MainActor
@Suite("Text to speech sheet", .serialized)
struct TextToSpeechViewModelTests {
    private func sheet(
        language: String = "pt-BR", replacing: VoiceOverClip? = nil, script: String? = nil, speaker: FakeNarrationSpeaker = FakeNarrationSpeaker()
    ) -> TextToSpeechViewModel {
        TextToSpeechViewModel(speaker: speaker, previews: SoundPreviewPlayer(), replacing: replacing, script: script, suggestedLanguage: language)
    }

    @Test func startsInTheTakesLanguageWithItsBestVoice() {
        let speech = sheet()
        #expect(speech.language == "pt-BR")
        #expect(speech.voiceID == "pt.felipe")
        #expect(!speech.hasOnlyCompactVoices)
        #expect(speech.languages.first == "pt-BR")
        speech.language = "en-US"
        #expect(speech.voiceID == "en.alex")
        #expect(speech.hasOnlyCompactVoices)
    }

    @Test func aLanguageWithoutVoicesGoesToTheNearest() {
        #expect(sheet(language: "pt-PT").language == "pt-BR")
        #expect(sheet(language: "en-GB").language == "en-US")
    }

    @Test func keepsTheTextUnderItsLimitAndOffersTheScript() {
        let speech = sheet(script: "Roteiro da take.")
        #expect(!speech.canMake)
        speech.text = String(repeating: "a", count: TextToSpeechViewModel.characterLimit + 50)
        #expect(speech.text.count == TextToSpeechViewModel.characterLimit)
        speech.useScript()
        #expect(speech.text == "Roteiro da take.")
        #expect(speech.canMake)
    }

    @Test func startsFromTheNarrationBeingChanged() {
        var clip = VoiceOverClip(fileName: "old.m4a", duration: 3, anchor: 1)
        clip.spoken = SpokenNarration(text: "Texto antigo", voiceID: "pt.luciana", language: "pt-BR", speed: 1.25)
        let speech = sheet(language: "en-US", replacing: clip)
        #expect(speech.text == "Texto antigo")
        #expect(speech.language == "pt-BR")
        #expect(speech.voiceID == "pt.luciana")
        #expect(speech.speed == 1.25)
    }

    @Test func handsTheMadeNarrationOver() async throws {
        let speech = sheet()
        speech.text = "Uma narração curta."
        speech.speed = 1.25
        let made: (SpokenNarration, String, TimeInterval) = await withCheckedContinuation { continuation in
            speech.make { continuation.resume(returning: ($0, $1, $2)) }
        }
        defer { EditMediaFiles.remove([made.1]) }
        #expect(made.0 == SpokenNarration(text: "Uma narração curta.", voiceID: "pt.felipe", language: "pt-BR", speed: 1.25))
        #expect(EditMediaFiles.exists(made.1))
        #expect(made.2 > 0.5)
        #expect(speech.phase == .writing)
    }

    @Test func aCancelAddsNothing() async throws {
        let speech = sheet(speaker: FakeNarrationSpeaker(delay: .seconds(5)))
        speech.text = "Uma narração que demora."
        var handed = false
        speech.make { _, _, _ in handed = true }
        #expect(speech.phase == .making)
        speech.cancel()
        #expect(speech.phase == .writing)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!handed)
    }
}
