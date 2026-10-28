//
//  TextEffectSparkle.swift
//  Cue Studio
//

import CoreGraphics

/// A short twinkle on the Gold effect: where it shows, how big it gets, and when, as a fraction of the way the glint crosses
/// the text (it shines as the glint passes it). Chosen once from the words (`TextEffectSprites`), so every frame of the
/// preview and the export shows the same ones.
nonisolated struct TextEffectSparkle: Hashable, Sendable {
    let position: CGPoint
    /// Its width at its brightest, in pixels.
    let size: CGFloat
    /// 0 to 1: how far along the glint's way it sits.
    let along: Double
    /// Turned this much at its brightest, in radians.
    let spin: CGFloat
    /// Whether it also twinkles as the text goes.
    let onExit: Bool
}
