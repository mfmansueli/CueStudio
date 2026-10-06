//
//  WelcomeDot.swift
//  Cue Studio
//

import SwiftUI

/// One of the C's dots, as the star lights it (09 §12): where it is in the 390 × 844 frame of the board, how big and what colour, when
/// the star reaches it, and how it pops, flares and rings.
struct WelcomeDot: Sendable {
    let point: CGPoint
    let radius: CGFloat
    let color: Color
    /// The star arrives at this second.
    let hit: Double
    /// The other dots twinkle instead of shining steadily.
    let twinkles: Bool
    /// How it swells at the hit (×2.0 … ×2.6), settling back to 1 over 0.35 s.
    let pop: PoseTrack
    /// The cross of light: opens with the hit and fades in half a second.
    let flare: PoseTrack
    /// The white ring that opens around it.
    let ring: PoseTrack
    /// The nine sparks that leave it.
    let sparks: [WelcomeSpark]

    /// - Parameters:
    ///   - index: its place on the C (0...4); the burst of sparks turns and reaches further with it.
    ///   - peak: how far it swells at the hit.
    init(index: Int, point: CGPoint, radius: CGFloat, color: Color, hit: Double, peak: Double, twinkles: Bool) {
        self.point = point
        self.radius = radius
        self.color = color
        self.hit = hit
        self.twinkles = twinkles
        pop = PoseTrack(curve: .cssEaseOut, [
            .init(hit - 0.05, opacity: 0, scale: 0), .init(hit, scale: peak), .init(hit + 0.35),
        ])
        flare = PoseTrack(curve: .cssEaseOut, [
            .init(hit - 0.04, opacity: 0, scale: 0, rotation: twinkles ? 45 : 0), .init(hit, scale: 1.15),
            .init(hit + 0.5, opacity: 0, scale: 0.2, rotation: twinkles ? -20 : 0),
        ])
        ring = PoseTrack(curve: .css(0.1, 0.7, 0.3, 1), [
            .init(hit - 0.01, opacity: 0, scale: 0.5), .init(hit, opacity: 0.9, scale: 0.5),
            .init(hit + 0.5, opacity: 0, scale: 3 + Double(index) * 0.5),
        ])
        sparks = WelcomeSpark.burst(index, start: hit)
    }
}
