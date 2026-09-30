//
//  SpeechLoudness.swift
//  Cue Studio
//

import Foundation

/// How loud the speaking parts of a sound are, so "Compare with original" plays the untreated take
/// as loud as the treated one: louder always sounds better, and the comparison would lie.
nonisolated enum SpeechLoudness {
    /// Readings quieter than this (dBFS) are pauses and room, not speech.
    static let floor: Float = -45

    /// The average power of the readings louder than `floor`, in dBFS; nil when nothing is.
    static func level(of levels: [Float]) -> Float? {
        let spoken = levels.filter { $0 > floor }
        guard !spoken.isEmpty else { return nil }
        let power = spoken.reduce(0.0) { $0 + pow(10, Double($1) / 10) } / Double(spoken.count)
        return Float(10 * log10(power))
    }

    /// The volume that makes a sound at `level` as loud as one at `target`.
    static func volume(matching level: Float, to target: Float) -> Double {
        pow(10, Double(target - level) / 20)
    }

    static func level(ofAudio url: URL) throws -> Float? {
        level(of: try AudioLevelReader.levels(of: url, interval: 0.05))
    }
}
