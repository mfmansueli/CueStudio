//
//  VoiceLeveling.swift
//  Cue Studio
//

import Foundation

/// "Even out volume" in a montage: how much each recording's speech is raised or lowered to sound as loud as the take's. A
/// recording more than a little off is brought to it, within limits: never raised more than `maximumBoost` (room noise would
/// come up with it), never lowered more than `maximumCut`. A gain of 0 dB leaves the recording as it is. A recording is never
/// raised past `AudioCeiling` (`AudioCeiling.leveled`), so evening out can't clip.
nonisolated enum VoiceLeveling {
    /// Most a recording is raised, in dB.
    static let maximumBoost: Float = 9
    /// Most a recording is lowered, in dB.
    static let maximumCut: Float = -12
    /// Differences smaller than this aren't heard: left as they are.
    static let tolerance: Float = 1

    /// The gain in dB for each recording with speech (`levels`: speech loudness in dBFS, nil key the take). The take is the
    /// reference when it speaks, else the loudest of the others, so nothing is raised more than it must be.
    static func gains(levels: [UUID?: Float]) -> [UUID?: Float] {
        guard levels.count > 1, let target = levels[nil] ?? levels.values.max() else { return [:] }
        var gains: [UUID?: Float] = [:]
        for (id, level) in levels {
            let difference = target - level
            guard abs(difference) >= tolerance else { continue }
            gains[id] = min(max(difference, maximumCut), maximumBoost)
        }
        return gains
    }
}
