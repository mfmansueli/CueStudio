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

    /// Nine sparks round a dot: 40° apart, three sizes, four reaches and four colours, each burst turned 13° from the one before. They are
    /// out in 0.03 s and gone 0.55 s after the hit.
    static func burst(_ index: Int, start: Double) -> [WelcomeSpark] {
        let sizes: [CGFloat] = [3, 2, 2.5]
        let colors: [Color] = [.white, Palette.starWarm, .white, Palette.starGold]
        return (0..<9).map { step in
            let distance = 18 + Double(index) * 3 + Double(step % 4) * 7
            return WelcomeSpark(
                angle: Double(index) * 13 + Double(step) * 40, size: sizes[step % 3], color: colors[step % 4],
                track: flight(Timing(start: start, peakAfter: 0.03, endAfter: 0.55, from: 2, to: 5, scale: 1.4), distance: distance)
            )
        }
    }

    /// Seven sparks off a word the star has landed on: out in 0.04 s and gone after 0.5 s.
    static func word(start: Double) -> [WelcomeSpark] {
        let sizes: [CGFloat] = [2.5, 2, 3]
        let colors: [Color] = [.white, Palette.acc, Palette.starWarm]
        return (0..<7).map { step in
            WelcomeSpark(
                angle: -90 + Double(step) * 51, size: sizes[step % 3], color: colors[step % 3],
                track: flight(Timing(start: start, peakAfter: 0.04, endAfter: 0.5, from: 4, to: 10, scale: 1.3), distance: 26 + Double(step % 3) * 7)
            )
        }
    }

    /// Twelve sparks of the explosion on the last dot: 30° apart, yellow and cream, three reaches, out in 0.05 s and gone after 1.1 s.
    static func explosion(start: Double) -> [WelcomeSpark] {
        let distances: [Double] = [48, 60, 44, 64, 52, 62, 46, 66, 54, 60, 48, 64]
        let sizes: [CGFloat] = [4, 3, 5, 3]
        return (0..<12).map { step in
            WelcomeSpark(
                angle: Double(step) * 30, size: sizes[step % 4], color: step.isMultiple(of: 2) ? Palette.acc : Palette.starCream,
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

    /// `count` sparks from `startAngle`, `step` degrees apart, cycling through the given reaches, sizes and colours.
    static func spread(
        count: Int, startAngle: Double, step: Double, distances: [Double], sizes: [CGFloat], colors: [Color], timing: Timing
    ) -> [WelcomeSpark] {
        (0..<count).map { index in
            WelcomeSpark(
                angle: startAngle + Double(index) * step, size: sizes[index % sizes.count], color: colors[index % colors.count],
                track: flight(timing, distance: distances[index % distances.count])
            )
        }
    }

    private static func flight(_ timing: Timing, distance: Double) -> PoseTrack {
        PoseTrack(curve: .css(0.1, 0.7, 0.3, 1), [
            .init(timing.start, opacity: 0, scale: 1, x: timing.from), .init(timing.start + timing.peakAfter, scale: timing.scale, x: timing.to),
            .init(timing.start + timing.endAfter, opacity: 0, scale: timing.scale == 1 ? 1 : 0.3, x: distance),
        ])
    }
}
