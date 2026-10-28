//
//  TextEffectRandom.swift
//  Cue Studio
//

import Foundation

/// Numbers that look random but come out the same from the same seed (SplitMix64), so an effect's sparkles are where they
/// were in every frame, every preview and every export.
nonisolated struct TextEffectRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// 0 to 1.
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value >> 11) / Double(1 << 53)
    }
}
