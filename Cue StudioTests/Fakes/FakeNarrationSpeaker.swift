//
//  FakeNarrationSpeaker.swift
//  Cue StudioTests
//

import Foundation
import os
@testable import Cue_Studio

/// Text to speech without the synthesizer: a few voices, and "speech" that is a harmonic tone a twentieth of a second per
/// character long, with `silence` before and after (as a voice leaves), after waiting `delay` (cancellable). Counts what it said.
nonisolated final class FakeNarrationSpeaker: NarrationSpeaking {
    static let voicesOnDevice = [
        NarrationVoice(id: "pt.luciana", name: "Luciana", language: "pt-BR", quality: .standard),
        NarrationVoice(id: "pt.felipe", name: "Felipe", language: "pt-BR", quality: .enhanced),
        NarrationVoice(id: "en.samantha", name: "Samantha", language: "en-US", quality: .standard),
        NarrationVoice(id: "en.alex", name: "Alex", language: "en-US", quality: .standard),
    ]
    static let secondsPerCharacter = 0.05
    static let silence = 0.4

    let delay: Duration?
    private let said = OSAllocatedUnfairLock<[String]>(initialState: [])

    init(delay: Duration? = nil) {
        self.delay = delay
    }

    var texts: [String] { said.withLock { $0 } }

    func voices() -> [NarrationVoice] { Self.voicesOnDevice }

    func speak(_ text: String, voiceID: String) async throws -> URL {
        if let delay { try await Task.sleep(for: delay) }
        try Task.checkCancellation()
        said.withLock { $0.append(text) }
        let spoken = max(0.5, Double(text.count) * Self.secondsPerCharacter)
        return try TestVoice.make(seconds: spoken + 2 * Self.silence, loud: [Self.silence...(Self.silence + spoken)])
    }

    /// How long the speech itself is for `text`.
    static func spokenLength(of text: String) -> TimeInterval {
        max(0.5, Double(text.count) * secondsPerCharacter)
    }
}
