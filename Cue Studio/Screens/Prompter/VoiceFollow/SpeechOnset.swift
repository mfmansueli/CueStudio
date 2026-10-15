//
//  SpeechOnset.swift
//  Cue Studio
//

import Foundation

/// Whether the creator has really started to speak, from the microphone's level alone: what starts Voice Following's text when the words
/// can't be recognized here (it then moves while they talk). A voice is loud for most of a stretch; a click, a bump on the desk or a cough
/// is loud for a moment. So it takes `required` seconds of sound above the room (`VoiceFollowGate.counts`) within `window` seconds before it
/// counts, and steady room noise never does (the gate leaves it out). Once started it stays started until `reset()`, when the text plays again.
nonisolated struct SpeechOnset: Equatable, Sendable {
    /// Loud sound adding up to this much…
    var required: TimeInterval = 0.25
    /// …within this long.
    var window: TimeInterval = 0.6

    private(set) var hasStarted = false
    /// The loud buffers heard lately, as the moment each one ended and how long it was.
    private var loud: [Stretch] = []

    private struct Stretch: Equatable, Sendable {
        let end: TimeInterval
        let duration: TimeInterval
    }

    /// One buffer: `duration` of audio that ended at `time`, loud enough to be a voice or not.
    mutating func hear(isLoud: Bool, at time: TimeInterval, duration: TimeInterval) {
        guard !hasStarted else { return }
        loud.removeAll { $0.end <= time - window }
        guard isLoud else { return }
        loud.append(Stretch(end: time, duration: max(0, duration)))
        let heard = loud.reduce(0) { total, stretch in total + min(stretch.duration, stretch.end - (time - window)) }
        if heard >= required - 0.000_1 { hasStarted = true }
    }

    /// The text plays again: it waits for the voice to start again.
    mutating func reset() {
        hasStarted = false
        loud = []
    }
}
