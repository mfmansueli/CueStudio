//
//  TextEffectPieceState.swift
//  Cue Studio
//

import CoreGraphics

/// Where one letter (or word) of an effect is at a moment: moved, turned and grown around its middle, how opaque, how lit
/// (Neon) and how far it has lifted off its shadow (Wave). At rest: in its place, whole, lit.
nonisolated struct TextEffectPieceState: Hashable, Sendable {
    /// Pixels, y up.
    var offset: CGPoint = .zero
    /// Radians, counterclockwise (Core Image's).
    var rotation: CGFloat = 0
    var scale: CGFloat = 1
    var opacity: CGFloat = 1
    /// 0 (the tube unlit) to 1 (lit).
    var lit: CGFloat = 1
    /// 0 (resting on its shadow) to 1 (well above it): its shadow fades as it lifts.
    var lift: CGFloat = 0

    static let rest = TextEffectPieceState()
}
