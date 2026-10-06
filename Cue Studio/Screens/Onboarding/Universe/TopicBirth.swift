//
//  TopicBirth.swift
//  Cue Studio
//

import SwiftUI

/// A topic becoming a world (1.2, 09 §14b): the chip lights, a light leaves it, travels round the universe and lands on the topic's orbit in
/// sparks, rings and streaks; the planet springs out, the orbit draws and its name arrives. The moments are the board's own: the board plays
/// this once, tapping a chip at 2.6 s, and every layer of it is read from its motion at `age + 2.6` (`MotionClip`, layers named below).
struct TopicBirth: Sendable {
    let color: Color
    let tap: Date
    /// The chip's centre, and where the world lands, in the chapter's space.
    let from: CGPoint
    let to: CGPoint
    /// The core ("YOU"): the route bows away from it and never crosses it.
    let core: CGPoint

    // MARK: - Times

    static let clip = MotionLibrary.clip("1.2_topics")
    /// The second of the board at which its demo taps the chip.
    static let boardTap = 2.6
    /// The light leaves 0.15 s after the tap and lands 1.75 s after it (the flight takes 1.6 s, `cubic-bezier(.5,0,.3,1)`).
    static let landing = 1.75
    /// Everything of the birth that the overlay draws is over by here (the last glint, the streaks and the rings).
    static let duration = 3.4

    /// The pose of a layer of the board `age` seconds after the tap. Past six seconds the board loops; a world, once born, stays.
    static func pose(_ layer: String, at age: Double) -> MotionPose {
        clip.pose(of: layer, at: min(age, 6) + boardTap)
    }

    /// The oval of light crossing the chip: 0.12–0.64 s.
    static let sweep = PoseTrack(curve: .css(0.5, 0, 0.2, 1), [
        .init(0.12, opacity: 0, scale: 0), .init(0.16, opacity: 1, scale: 0), .init(0.62, opacity: 1, scale: 1), .init(0.64, opacity: 0, scale: 1),
    ])

    /// The bar that marks the chip pops in, 0.05–0.30 s, with a spring's overshoot.
    static let bar = PoseTrack(curve: .css(0.3, 1.5, 0.5, 1), [.init(0.05, opacity: 0, scale: 0), .init(0.30)])

    /// The ring of light round "Continue" after the landing (1.6–2.9 s: 0 → 6 pt at 35%, then 16 pt at 0%).
    static let button = PoseTrack(curve: .cssEaseOut, [
        .init(1.6, opacity: 0, scale: 0), .init(1.9, opacity: 0.35, scale: 6), .init(2.9, opacity: 0, scale: 16),
    ])

    // MARK: - The board's layers

    /// The ring, the cross and the eight sparks on the chip at the tap (`unsq`).
    static let chipRing = "L80"
    static let chipCross = "L82"
    static let chipSparks = (83...90).map { "L\($0)" }
    /// The light on the route: the line that draws behind it, the bright stretch at its tail, its head, and the eight dots that follow the head.
    static let routeLine = "L25"
    static let routeTail = "L26"
    static let head = "L27"
    static let followers = (28...35).map { "L\($0)" }
    /// The five glints on the route: the layer, how far along the route (0...1), and how big across (pt).
    static let glints: [(layer: String, along: Double, size: CGFloat)] = [
        ("L36", 0.188, 14), ("L37", 0.365, 10), ("L38", 0.545, 14), ("L39", 0.716, 10), ("L40", 0.862, 14),
    ]
    /// At the landing: nine sparks, ten streaks, three rings and a cross of light.
    static let landingSparks = (60...68).map { "L\($0)" }
    static let streaks = (49...58).map { "L\($0)" }
    static let rings = ["L21", "L22", "L59"]
    static let landingCross = "L23"
    /// The planet (springs out), its orbit (draws), the white light that runs round the orbit once, and the name.
    static let planet = "L16"
    static let orbit = "L13"
    static let orbitLight = "L14"
    static let label = "L24"

    // MARK: - The route

    /// The light's way: out of the chip, round the universe on the side away from the core, and into the orbit (the board: `M74 570 C 170 500,
    /// 392 470, 325 317`, out of the chip, under the universe and up its right side). Both controls lie on the same side of the chord, the one
    /// farther from the core.
    var path: Path {
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: control1, control2: control2)
        return path
    }

    private var bow: CGPoint {
        let chord = CGPoint(x: to.x - from.x, y: to.y - from.y)
        let length = max(hypot(chord.x, chord.y), 1)
        var normal = CGPoint(x: -chord.y / length, y: chord.x / length)
        let middle = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        // The core on the chord (or nearly): the board's side, to the right when going up.
        let side = (normal.x * (middle.x - core.x) + normal.y * (middle.y - core.y))
        if side < 0 || (abs(side) < 8 && normal.x < 0) { normal = CGPoint(x: -normal.x, y: -normal.y) }
        let amount = min(150, 0.5 * length + 40)
        return CGPoint(x: normal.x * amount, y: normal.y * amount)
    }

    var control1: CGPoint {
        CGPoint(x: from.x + (to.x - from.x) * 0.25 + bow.x * 1.3, y: from.y + (to.y - from.y) * 0.25 + bow.y * 1.3)
    }

    var control2: CGPoint {
        CGPoint(x: from.x + (to.x - from.x) * 0.75 + bow.x * 1.3, y: from.y + (to.y - from.y) * 0.75 + bow.y * 1.3)
    }

    func point(at progress: Double) -> CGPoint {
        let u = min(1, max(0, progress)), v = 1 - u
        let x = v * v * v * from.x + 3 * v * v * u * control1.x + 3 * v * u * u * control2.x + u * u * u * to.x
        let y = v * v * v * from.y + 3 * v * v * u * control1.y + 3 * v * u * u * control2.y + u * u * u * to.y
        return CGPoint(x: x, y: y)
    }
}
