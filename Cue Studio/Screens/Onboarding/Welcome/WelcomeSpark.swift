//
//  WelcomeSpark.swift
//  Cue Studio
//

import SwiftUI

/// A speck of light thrown out of a hit: it leaves at `angle` and ends `distance` away, swelling at first and shrinking as it goes.
struct WelcomeSpark: Sendable {
    let angle: Double
    let size: CGFloat
    let color: Color
    /// `x` is how far from the centre, `scale` its size, `opacity` its light.
    let track: PoseTrack

    private init(angle: Double, size: CGFloat, color: Color, track: PoseTrack) {
        self.angle = angle
        self.size = size
        self.color = color
        self.track = track
    }

    /// Four small sparks round a dot: 90° apart, each burst turned 23° from the one before, short reaches. They are out in 0.03 s and gone
    /// 0.45 s after the hit.
    static func burst(_ index: Int, start: Double) -> [WelcomeSpark] {
        let sizes: [CGFloat] = [2.4, 1.8]
        let colors: [Color] = [.white, Palette.Universe.starWarm]
        return (0..<4).map { step in
            let distance = 14 + Double(index) * 2 + Double(step % 2) * 5
            return WelcomeSpark(
                angle: Double(index) * 23 + Double(step) * 90, size: sizes[step % 2], color: colors[step % 2],
                track: flight(Timing(start: start, peakAfter: 0.03, endAfter: 0.45, from: 2, to: 5, scale: 1.2), distance: distance)
            )
        }
    }

    /// Six sparks of the explosion on the last dot: 60° apart, yellow and cream, out in 0.05 s and gone after 1.1 s.
    static func explosion(start: Double) -> [WelcomeSpark] {
        let distances: [Double] = [54, 62, 50, 64, 56, 60]
        let sizes: [CGFloat] = [4, 3, 3.5]
        return (0..<6).map { step in
            WelcomeSpark(
                angle: 15 + Double(step) * 60, size: sizes[step % 3], color: step.isMultiple(of: 2) ? Palette.acc : Palette.Universe.starCream,
                track: flight(Timing(start: start, peakAfter: 0.05, endAfter: 1.1, from: 2, to: 8, scale: 1), distance: distances[step])
            )
        }
    }

    /// How a burst flies: it starts at `start`, is out `peakAfter` later at `to` pt (swelled to `scale`) and gone `endAfter` after the start.
    struct Timing {
        let start: Double
        let peakAfter: Double
        let endAfter: Double
        let from: Double
        let to: Double
        let scale: Double
    }

    private static func flight(_ timing: Timing, distance: Double) -> PoseTrack {
        PoseTrack(curve: .css(0.1, 0.7, 0.3, 1), [
            .init(timing.start, opacity: 0, scale: 1, x: timing.from), .init(timing.start + timing.peakAfter, scale: timing.scale, x: timing.to),
            .init(timing.start + timing.endAfter, opacity: 0, scale: timing.scale == 1 ? 1 : 0.3, x: distance),
        ])
    }
}
