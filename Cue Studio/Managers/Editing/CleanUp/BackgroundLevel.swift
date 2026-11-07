//
//  BackgroundLevel.swift
//  Cue Studio
//

import Foundation

/// A recording's loudness in three numbers, from the readings Clean Up already takes (dBFS, one every 50 ms): the background under
/// the voice (`floor`, what the quietest tenth of the readings reaches), how much that background moves (`spread`, from the quietest
/// 2 % up to the floor: about 1 dB for a fan, 3 to 4 for traffic) and the voice (`speech`, what the loudest tenth reaches). Readings
/// of digital silence (under −100 dBFS, before the microphone starts) aren't sound and don't count. Pure, so it is tested with
/// made-up levels.
nonisolated struct BackgroundLevel: Hashable, Sendable {
    var floor: Float
    var spread: Float
    var speech: Float

    /// Under this many readings (a second) there is too little to tell a background from a voice.
    static let minimumReadings = 20

    /// What the quietest 2 % of the recording reaches.
    var lowest: Float { floor - spread }

    /// Nil for a recording too short (or silent) to measure.
    static func measure(_ levels: [Float]) -> BackgroundLevel? {
        let sound = levels.filter { $0 > -100 }.sorted()
        guard sound.count >= minimumReadings else { return nil }
        func reached(by share: Double) -> Float { sound[min(sound.count - 1, Int(Double(sound.count) * share))] }
        let floor = reached(by: 0.1)
        return BackgroundLevel(floor: floor, spread: floor - reached(by: 0.02), speech: reached(by: 0.9))
    }
}
