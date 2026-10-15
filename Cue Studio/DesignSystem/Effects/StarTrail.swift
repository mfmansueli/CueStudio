//
//  StarTrail.swift
//  Cue Studio
//

import SwiftUI

/// The star of the first flight crossing a chapter, with its tail (`StarRibbon`), on a canvas the size of the view. The scene says where the
/// head is at any second (from the view's top left) and which second is being drawn, so the tail follows the head without a clock of its own.
struct StarTrail: View {
    let time: Double
    let head: (Double) -> StarRibbon.Point

    var body: some View {
        Canvas { context, _ in
            let trail = StarRibbon.trail(at: time, head: head)
            StarRibbon.draw(trail, in: &context)
            if let first = trail.first { StarRibbon.head(at: first.point, opacity: first.opacity, spin: time, in: &context) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
