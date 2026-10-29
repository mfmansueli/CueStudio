//
//  SkinLookFixtures.swift
//  Cue StudioTests
//

@testable import Cue_Studio

extension SkinLook {
    /// Only the first engine's smoothing at `value`: what an edit made before today's engine draws.
    static func firstEngine(_ value: Double) -> SkinLook {
        SkinLook(smoothing: .firstEngine(value))
    }

    /// Only today's smoothing at `amount`, with `texture`.
    static func smoothing(_ amount: Double, texture: Double = SkinBeautyCalibration.defaultTexture) -> SkinLook {
        SkinLook(smoothing: SkinSmoothing(amount: amount, texture: texture))
    }
}
