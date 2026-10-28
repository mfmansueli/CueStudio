//
//  TimelineRevealSpring.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The timeline settling after a drag up or down, or after ▾: from where it was (`TimelineGeometry.Input.reveal`) to every
/// track out (1) or the current track alone (0), carried on by the finger's speed, on a spring that passes the mark a little.
/// With Reduce Motion it eases there without the finger's speed and never passes it (critically damped). Pure, so the motion
/// is tested without a screen.
nonisolated struct TimelineRevealSpring: Equatable, Sendable {
    /// How long a swing takes, and how far past the mark it goes (as SwiftUI's `bounce`).
    static let response: Double = 0.42
    static let bounce: Double = 0.18
    /// The most of the finger's speed it keeps (reveal per second): a hard throw doesn't fling the tracks past their place.
    static let maximumSpeed: CGFloat = 4
    /// Longer than any settle takes: it stops there whatever is left.
    static let longest: TimeInterval = 1.2

    let from: CGFloat
    let to: CGFloat
    /// Reveal per second at the start, only toward `to` (a finger going the other way doesn't push it back); none when it
    /// mustn't pass the mark (a push would carry it past even critically damped).
    let velocity: CGFloat
    let passesTheMark: Bool

    init(from: CGFloat, to: CGFloat, velocity: CGFloat = 0, passesTheMark: Bool = true) {
        self.from = from
        self.to = to
        let toward = passesTheMark && (to - from) * velocity > 0 ? velocity : 0
        self.velocity = min(Self.maximumSpeed, max(-Self.maximumSpeed, toward))
        self.passesTheMark = passesTheMark
    }

    /// Where it is `time` seconds in.
    func value(at time: TimeInterval) -> CGFloat {
        let time = max(0, time)
        let natural = 2 * Double.pi / Self.response
        let damping = passesTheMark ? 1 - Self.bounce : 1
        let start = Double(from - to)
        let speed = Double(velocity)
        let decay = exp(-damping * natural * time)
        let offset: Double
        if damping < 1 {
            let swing = natural * (1 - damping * damping).squareRoot()
            offset = decay * (start * cos(swing * time) + (speed + damping * natural * start) / swing * sin(swing * time))
        } else {
            offset = decay * (start + (speed + natural * start) * time)
        }
        return to + CGFloat(offset)
    }

    /// It has come to rest: within a hair of the mark and nearly still, or it has run its longest.
    func isSettled(at time: TimeInterval) -> Bool {
        guard time < Self.longest else { return true }
        let step: TimeInterval = 1 / 240
        let now = value(at: time)
        let speed = abs(value(at: time + step) - now) / CGFloat(step)
        return abs(now - to) < 0.002 && speed < 0.05
    }
}
