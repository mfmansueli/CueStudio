//
//  VoiceFollowGate.swift
//  Cue Studio
//

import Foundation

/// Decides whether the creator is speaking from the microphone level. Keeps scrolling through the
/// short gaps between words and stops on a real pause.
nonisolated struct VoiceFollowGate: Sendable {
    /// Level above which the input counts as speech, in dBFS.
    var threshold: Float = -40
    /// How long scrolling continues after the last loud sample.
    var hangover: TimeInterval = 0.6
    private var lastSpeech: TimeInterval?

    init(threshold: Float = -40, hangover: TimeInterval = 0.6) {
        self.threshold = threshold
        self.hangover = hangover
    }

    mutating func isSpeaking(level: Float?, at time: TimeInterval) -> Bool {
        if let level, level > threshold {
            lastSpeech = time
            return true
        }
        guard let lastSpeech else { return false }
        return time - lastSpeech <= hangover
    }

    /// 0...1 for level meters: -50 dB and below is silent.
    static func normalized(_ level: Float?) -> Double {
        guard let level else { return 0 }
        return Double(min(1, max(0, (level + 50) / 50)))
    }
}
