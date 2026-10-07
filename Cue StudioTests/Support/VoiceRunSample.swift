//
//  VoiceRunSample.swift
//  Cue StudioTests
//

import Foundation

/// One script written for a persona on a device (`VoicePersonaDeviceTests`), as it is kept for the comparison between runs
/// (`VoiceRunMetrics`): the same twelve creators and three ideas written with no voice, with the voice as it was and with the voice as it is.
nonisolated struct VoiceRunSample: Codable, Hashable, Sendable {
    /// `VoicePersona.id`.
    let persona: String
    let ideaIndex: Int
    let idea: String
    /// "no-voice" or "voice": what the request carried.
    let condition: String
    /// The creator's own words for the run ("before", "after"): what the code was when it was written.
    let run: String
    let title: String?
    let text: String?
    /// Why nothing was written (the error), when nothing was.
    let failure: String?
    let seconds: Double
    /// How many times the request went out: 1, or 2 when the checker asked for another try (always 1 before it existed).
    let attempts: Int

    var wasWritten: Bool { text?.isEmpty == false }
}
