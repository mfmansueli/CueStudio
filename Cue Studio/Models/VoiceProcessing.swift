//
//  VoiceProcessing.swift
//  Cue Studio
//

import Foundation

/// How the take's own sound is treated before it's mixed: its volume, and (version 2) Enhance
/// Voice and Reduce Background Noise, each off, soft or strong and independent of the other.
/// Version 1 is the treatment edits made before these settings had (one switch each), kept so
/// they sound as they did. Only the take's sound is treated: music, voice-overs and videos over
/// the take are left as they are. The recording itself never changes.
nonisolated struct VoiceProcessing: Hashable, Sendable {
    /// The treatment's version: 1 for edits made before the levels, 2 since.
    let version: Int
    let volume: Double
    /// Version 1's switches.
    let enhancesVoice: Bool
    let reducesNoise: Bool
    /// Version 2's levels.
    let enhancement: AudioStrength
    let noise: AudioStrength

    /// Whether the sound is changed at all.
    var isNeeded: Bool {
        guard abs(volume - 1) < 0.000_1 else { return true }
        return version == 1 ? (enhancesVoice || reducesNoise) : (enhancement != .off || noise != .off)
    }

    /// The same volume, untreated: what "Compare with original" plays.
    var untreated: VoiceProcessing {
        VoiceProcessing(version: 2, volume: volume, enhancesVoice: false, reducesNoise: false, enhancement: .off, noise: .off)
    }
}
