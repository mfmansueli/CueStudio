//
//  WordsRenderer.swift
//  Cue Studio
//

import SwiftUI

/// Draws `WordsFromLight`: each word rises out of a blur into place after the one before it, carrying a fading violet glow.
struct WordsRenderer: TextRenderer {
    var elapsed: Double
    var stagger: Double
    var reduceMotion: Bool
    var glows: Bool

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                let index = run[WordIndexAttribute.self]?.index ?? 0
                let age = elapsed - Double(index) * stagger
                let progress = reduceMotion ? min(1, max(0, elapsed / 0.4)) : min(1, max(0, age / CueMotion.Duration.wordFromLight))
                let glow = reduceMotion || !glows ? 0 : max(0, 1 - max(0, age - CueMotion.Duration.wordFromLight) / 0.9)
                var copy = context
                copy.opacity = progress
                if !reduceMotion {
                    copy.translateBy(x: 0, y: 6 * (1 - progress))
                    copy.addFilter(.blur(radius: 8 * (1 - progress)))
                }
                if glow > 0, progress > 0 {
                    var glowing = copy
                    glowing.addFilter(.shadow(color: Palette.aiText.opacity(0.9 * glow), radius: 6))
                    glowing.draw(run)
                } else {
                    copy.draw(run)
                }
            }
        }
    }
}
