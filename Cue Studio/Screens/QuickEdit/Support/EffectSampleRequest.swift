//
//  EffectSampleRequest.swift
//  Cue Studio
//

import Foundation

/// What Text style's effect cards are drawn for: the creator's first words, the effect picked (its card plays) and whether
/// it may play. A new one draws them again (`TextEffectCardSamples.prepare`).
struct EffectSampleRequest: Hashable {
    let words: String
    let picked: TypePreset?
    let plays: Bool
}
