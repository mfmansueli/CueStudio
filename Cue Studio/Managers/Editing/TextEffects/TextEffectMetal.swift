//
//  TextEffectMetal.swift
//  Cue Studio
//

import Foundation

/// The Gold effect's metal as paint: its tonal bands from the bottom of a letter to the top (a darker horizon a little
/// under the middle, bright above it, a lit reflection below it, as polished metal shows the sky and the ground), the dark
/// edge around the letters and the shade inside their lower edges, and the glint's warmth.
nonisolated struct TextEffectMetal {
    let bands: [(CGFloat, TextEffectInk)]
    /// One flat tone of the metal: what the bands lean to when Shine is low.
    let flat: TextEffectInk
    let edge: TextEffectInk
    let shade: TextEffectInk
    let glint: TextEffectInk
    /// The bevelled frame around the letters, darker than the face, lit at the top.
    var frame: [(CGFloat, TextEffectInk)] {
        [(0, shade), (0.5, flat.darkened(0.35)), (1, flat.lightened(0.1))]
    }

    init(_ tone: MetalTone) {
        switch tone {
        case .gold:
            bands = [
                (0, TextEffectInk(hex: 0x8A5714)), (0.2, TextEffectInk(hex: 0xD29C38)), (0.4, TextEffectInk(hex: 0xFFE59C)),
                (0.47, TextEffectInk(hex: 0xB27720)), (0.6, TextEffectInk(hex: 0xE6B24B)), (0.84, TextEffectInk(hex: 0xFFF1C0)),
                (1, TextEffectInk(hex: 0xF2CC66)),
            ]
            flat = TextEffectInk(hex: 0xE2B04C)
            edge = TextEffectInk(hex: 0x3E2405)
            shade = TextEffectInk(hex: 0x5C3608)
            glint = TextEffectInk(hex: 0xFFF7DC)
        case .rose:
            bands = [
                (0, TextEffectInk(hex: 0x7E3E33)), (0.2, TextEffectInk(hex: 0xCB8774)), (0.4, TextEffectInk(hex: 0xFFD9CB)),
                (0.47, TextEffectInk(hex: 0xA65B4D)), (0.6, TextEffectInk(hex: 0xE5A28C)), (0.84, TextEffectInk(hex: 0xFFF0E9)),
                (1, TextEffectInk(hex: 0xF0B8A3)),
            ]
            flat = TextEffectInk(hex: 0xDE9C87)
            edge = TextEffectInk(hex: 0x3D1813)
            shade = TextEffectInk(hex: 0x5E2A22)
            glint = TextEffectInk(hex: 0xFFF3EE)
        case .silver:
            bands = [
                (0, TextEffectInk(hex: 0x4A4F58)), (0.2, TextEffectInk(hex: 0x9CA3AD)), (0.4, TextEffectInk(hex: 0xF4F7FB)),
                (0.47, TextEffectInk(hex: 0x6A707A)), (0.6, TextEffectInk(hex: 0xC8CDD5)), (0.84, TextEffectInk(hex: 0xFFFFFF)),
                (1, TextEffectInk(hex: 0xDDE2E8)),
            ]
            flat = TextEffectInk(hex: 0xC2C7CF)
            edge = TextEffectInk(hex: 0x1E2126)
            shade = TextEffectInk(hex: 0x30353D)
            glint = TextEffectInk(hex: 0xFFFFFF)
        }
    }

    /// The bands with their contrast for `shine` (0 to 1): low leans every band to the flat tone, high keeps them whole.
    func bands(shine: Double) -> [(CGFloat, TextEffectInk)] {
        let keep = 0.45 + 0.55 * min(max(shine, 0), 1)
        return bands.map { ($0.0, flat.mixed(with: $0.1, keep)) }
    }
}
