//
//  VoiceFollowGate.swift
//  Cue Studio
//

import Foundation

/// Decides whether the creator is speaking from the microphone level, one buffer at a time as the
/// buffers arrive. Keeps "speaking" through the short gaps between words and stops on a real
/// pause.
///
/// - In a quiet room, speech is anything above `threshold`, as it always was.
/// - In a noisy one (air conditioning, traffic, a fan), the room's own level is learned from the
///   quietest moments of the last few seconds (`noiseFloor`), and speech has to rise `margin`
///   above it, so steady noise never lights the indicator or moves the text.
/// - A sound has to last `attack` before it counts, so a click or a bump on the desk doesn't.
nonisolated struct VoiceFollowGate: Sendable {
    /// Level above which the input counts as speech in a quiet room, in dBFS.
    var threshold: Float = -40
    /// How far above the room's noise speech has to be, in dB.
    var margin: Float = 10
    /// How long "speaking" lasts after the last loud buffer.
    var hangover: TimeInterval = 0.6
    /// How long a loud stretch has to last before it counts.
    var attack: TimeInterval = 0.03
    /// How far back the room's quietest moment is looked for.
    var floorWindow: TimeInterval = 3

    /// The room's level, learned from the quietest moment of the last `floorWindow` seconds. Nil
    /// until a first stretch of the window has been heard.
    private(set) var noiseFloor: Float?

    /// The last loud buffer while speaking.
    private var lastSpeech: TimeInterval?
    /// When the current loud stretch began.
    private var loudSince: TimeInterval?
    /// The quietest level of each finished stretch of `floorBlock` seconds heard lately.
    private var floorBlocks: [(index: Int, minimum: Float)] = []
    /// The stretch being heard now.
    private var block: (index: Int, minimum: Float)?

    private static let floorBlock: TimeInterval = 0.5

    init(threshold: Float = -40, hangover: TimeInterval = 0.6) {
        self.threshold = threshold
        self.hangover = hangover
    }

    /// The level speech has to pass now.
    var effectiveThreshold: Float {
        guard let noiseFloor else { return threshold }
        return max(threshold, noiseFloor + margin)
    }

    /// Takes one buffer's level: `duration` of audio that arrived at `time`. Returns whether the
    /// creator is speaking.
    @discardableResult
    mutating func hear(level: Float, at time: TimeInterval, duration: TimeInterval) -> Bool {
        learnFloor(level, at: time)
        if level > effectiveThreshold {
            let start = loudSince ?? time - duration
            loudSince = start
            if isSpeaking(at: time) || time - start >= attack {
                lastSpeech = time
            }
        } else {
            loudSince = nil
        }
        return isSpeaking(at: time)
    }

    /// Whether the creator still counts as speaking at `time`: within `hangover` of the last loud
    /// buffer.
    func isSpeaking(at time: TimeInterval) -> Bool {
        guard let lastSpeech else { return false }
        return time - lastSpeech <= hangover
    }

    /// Seconds since the last loud buffer while speaking; nil when not speaking. A short gap is
    /// between two words; a longer one is a pause even before the hangover ends.
    func quietTime(at time: TimeInterval) -> TimeInterval? {
        guard let lastSpeech, isSpeaking(at: time) else { return nil }
        return max(0, time - lastSpeech)
    }

    /// 0...1 for level meters: -50 dB and below is silent.
    static func normalized(_ level: Float?) -> Double {
        guard let level else { return 0 }
        return Double(min(1, max(0, (level + 50) / 50)))
    }

    // MARK: - Room noise

    /// Keeps the quietest level of each half second; the floor is the quietest of the last
    /// `floorWindow`. Speech has gaps between words that fall back to the room's level, so the
    /// floor stays at the room's noise while someone talks.
    private mutating func learnFloor(_ level: Float, at time: TimeInterval) {
        let index = Int((time / Self.floorBlock).rounded(.down))
        guard let current = block, index != current.index else {
            block = (index, min(block?.minimum ?? level, level))
            return
        }
        floorBlocks.append(current)
        let oldest = index - Int((floorWindow / Self.floorBlock).rounded())
        floorBlocks.removeAll { $0.index < oldest }
        noiseFloor = floorBlocks.map(\.minimum).min()
        block = (index, level)
    }
}
