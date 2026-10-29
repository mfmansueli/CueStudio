//
//  SpokenNarration.swift
//  Cue Studio
//

import Foundation

/// What a voice-over spoken by the iPhone from text says and how (Text to speech): kept with the clip (`VoiceOverClip.spoken`)
/// so its text, voice or speed can be changed and it can be spoken again in place.
nonisolated struct SpokenNarration: Codable, Hashable, Sendable {
    /// The speeds offered, around the voice's natural pace (1).
    static let speedRange: ClosedRange<Double> = 0.75...1.5

    var text: String
    /// The system voice's identifier (`AVSpeechSynthesisVoice.identifier`).
    var voiceID: String
    /// The voice's language (BCP 47, "pt-BR").
    var language: String
    /// 0.75 to 1.5 of the voice's natural pace.
    var speed: Double

    init(text: String, voiceID: String, language: String, speed: Double = 1) {
        self.text = text
        self.voiceID = voiceID
        self.language = language
        self.speed = min(max(speed, Self.speedRange.lowerBound), Self.speedRange.upperBound)
    }
}
