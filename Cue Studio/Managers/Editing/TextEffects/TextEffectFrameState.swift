//
//  TextEffectFrameState.swift
//  Cue Studio
//

import CoreGraphics

/// A text effect at a moment (`TextEffectChoreography`): every piece's state, where the band of light is, how far each of
/// Headline's bands has wiped in, and which sparkles shine. Pure numbers, so the preview, the export and the tests agree.
nonisolated struct TextEffectFrameState: Hashable, Sendable {
    var pieces: [TextEffectPieceState]
    /// The band of light's center, in the drawing's pixels across, and its strength; nil when it isn't crossing.
    var sweepX: CGFloat?
    var sweepOpacity: CGFloat = 0
    /// Per line of Headline, the stretch of its band showing, as fractions of its width from the start side (0 to 1 is all).
    var bands: [ClosedRange<CGFloat>] = []
    /// The sparkles shining, each with how far through its twinkle it is (0 to 1).
    var sparkles: [Sparkle] = []
    /// Everything in its place: the still drawing stands for it.
    var isRest = false

    struct Sparkle: Hashable, Sendable {
        let index: Int
        let phase: CGFloat
    }
}
