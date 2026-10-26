//
//  RingCover.swift
//  Cue Studio
//

import SwiftUI

/// The star's dark cover with the ring's hole in it: a circle round `centre` that grows with `ring` (0 → 1) until it takes the whole screen,
/// so the page shows through. One even-odd shape, filled as it is: no mask, so no picture of the screen is drawn off it each frame.
nonisolated struct RingCover: Shape {
    var ring: CGFloat
    let centre: CGPoint

    var animatableData: CGFloat {
        get { ring }
        set { ring = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var cover = Path(rect)
        let radius = ring * hypot(rect.width, rect.height) * 1.05
        if radius > 0 {
            cover.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
        }
        return cover
    }
}
