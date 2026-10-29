//
//  NarrationSpeaking.swift
//  Cue Studio
//

import Foundation

/// What Text to speech speaks with: the voices on this device and a way to say a text into a sound file. The app's one is the
/// iPhone's own speech synthesizer (`SystemNarrationSpeaker`), offline; tests hand in their own.
protocol NarrationSpeaking: Sendable {
    /// Every voice installed now, in every language (novelty voices left out).
    func voices() -> [NarrationVoice]

    /// Says `text` with the voice `voiceID` at its natural pace into a sound file in the temporary folder, as fast as the device
    /// can. Throws `CancellationError` when the task is cancelled (the synthesizer stops at once).
    func speak(_ text: String, voiceID: String) async throws -> URL
}
