//
//  SystemNarrationSpeaker.swift
//  Cue Studio
//

import AVFoundation

/// Text to speech with the iPhone's own speech synthesizer (`AVSpeechSynthesizer.write`), offline: the voices installed now (the
/// compact ones every device has, and the Enhanced or Premium ones the creator downloaded), never a server. Novelty voices and
/// the creator's Personal Voice are left out (the first aren't for narration, the second asks for a permission of its own).
/// The voice speaks at its natural pace; `NarrationMaker` brings it to the speed asked for.
nonisolated final class SystemNarrationSpeaker: NarrationSpeaking {
    enum SpeakError: Error { case noVoice, nothingSaid, couldNotWrite }

    func voices() -> [NarrationVoice] {
        let installed = AVSpeechSynthesisVoice.speechVoices()
        // Each language's default voice, as the system picks it when no voice is named.
        let defaults = Set(Set(installed.map(\.language)).compactMap { AVSpeechSynthesisVoice(language: $0)?.identifier })
        return installed.compactMap { voice in
            guard !voice.voiceTraits.contains(.isNoveltyVoice), !voice.voiceTraits.contains(.isPersonalVoice) else { return nil }
            let quality: NarrationVoiceQuality = switch voice.quality {
            case .premium: .premium
            case .enhanced: .enhanced
            default: .standard
            }
            return NarrationVoice(
                id: voice.identifier, name: voice.name, language: voice.language, quality: quality,
                isSystemDefault: defaults.contains(voice.identifier),
                isEloquence: voice.identifier.contains(".eloquence.")
            )
        }
    }

    func speak(_ text: String, voiceID: String) async throws -> URL {
        guard let voice = try await Self.voice(voiceID) else { throw SpeakError.noVoice }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // The creator's VoiceOver speed and voice settings are theirs, not the narration's.
        utterance.prefersAssistiveTechnologySettings = false
        let url = URL.temporaryDirectory.appending(path: "Cue-speech-\(UUID().uuidString.prefix(8)).caf")
        let job = NarrationSpeechJob(url: url)
        do {
            try await withTaskCancellationHandler {
                try await job.run(utterance)
            } onCancel: {
                job.cancel()
            }
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        return url
    }

    /// The voice by its identifier. The system's voices can be missing for a moment while it refreshes them (measured 29/10 on an
    /// iPhone 15 Pro, right after the speech recognizer ran: a voice that had just spoken wasn't found), so it asks again for up to
    /// two seconds before giving up.
    private static func voice(_ id: String) async throws -> AVSpeechSynthesisVoice? {
        for attempt in 0..<9 {
            if let voice = AVSpeechSynthesisVoice(identifier: id) { return voice }
            if attempt < 8 { try await Task.sleep(for: .milliseconds(250)) }
        }
        return nil
    }
}
