//
//  WelcomeScript.swift
//  Cue Studio
//

import SwiftUI

/// The 1.1 opening (09 §12, `motion/README.md`, refined with the owner 02/11/2026): in a 390 × 844 frame a star comes in from the top
/// right on one smooth curve (`WelcomeFlight`), lights five dots that draw the C, draws the leg without lighting the sixth, skims three
/// words, returns and explodes into the sixth dot; then the wordmark, the title and the button arrive. Every moment is a pose read at the
/// second it is drawn, so the scene holds still once the last one is over.
enum WelcomeScript {
    /// The frame of the board; the scene is laid out in it, centred on the screen.
    static let frame = CGSize(width: 390, height: 844)
    /// Everything is in place (the button lands at 7.75 s, the gold light over the title is gone by 8.3 s).
    static let finalTime = 8.4

    // MARK: - The C

    /// The five dots the star lights, from the top right round to the bottom; the sixth is where it lands at the end.
    static let dots: [WelcomeDot] = [
        WelcomeDot(index: 0, point: CGPoint(x: 243, y: 180), radius: 4.5, color: .white, hit: 1.10, peak: 2.0, twinkles: false),
        WelcomeDot(index: 1, point: CGPoint(x: 179, y: 172), radius: 3.3, color: Palette.aiTextStrong, hit: 1.30, peak: 2.1, twinkles: true),
        WelcomeDot(index: 2, point: CGPoint(x: 135, y: 216), radius: 4.5, color: .white, hit: 1.50, peak: 2.25, twinkles: false),
        WelcomeDot(index: 3, point: CGPoint(x: 139, y: 272), radius: 3.3, color: Palette.aiTextStrong, hit: 1.70, peak: 2.4, twinkles: true),
        WelcomeDot(index: 4, point: CGPoint(x: 187, y: 308), radius: 4.5, color: .white, hit: 1.90, peak: 2.6, twinkles: false),
    ]

    /// The sixth dot: dim (40%) until the star returns at 5.05 s and explodes into it.
    static let cue = CGPoint(x: 247, y: 300)
    static let explosionTime = 5.05

    /// How much of the C's line is drawn: a quarter of it each time the star lands on a dot.
    static let line = PoseTrack([
        .init(1.13, scale: 0), .init(1.28, scale: 0.266), .init(1.33, scale: 0.266), .init(1.48, scale: 0.523), .init(1.53, scale: 0.523),
        .init(1.68, scale: 0.754), .init(1.73, scale: 0.754), .init(1.88, scale: 1),
    ])

    /// The leg, from the fifth dot toward the sixth: drawn between 1.95 and 2.25 s, in yellow.
    static let leg = PoseTrack([.init(1.95, scale: 0), .init(2.25, scale: 1)])

    /// The sixth dot, dim from 0.9 s to the explosion.
    static let dimCue = PoseTrack([
        .init(0.9, opacity: 0), .init(1.3, opacity: 0.4), .init(5.05, opacity: 0.4), .init(5.10, opacity: 0),
    ])

    /// The violet light behind the C, growing from 1.0 to 3.2 s.
    static let halo = PoseTrack(curve: .css(0.16, 1, 0.3, 1), [
        .init(1.0, opacity: 0, scale: 0.6), .init(3.2),
    ])

    // MARK: - The explosion

    /// The star becomes the sixth dot: the core swells ×2.2 and settles, a ring opens, a yellow cross opens and settles small, and its
    /// light washes over the sky and fades (`bloom`).
    static let core = PoseTrack(curve: .css(0.3, 1.3, 0.5, 1), [.init(5.0, scale: 0), .init(5.15, scale: 2.2), .init(5.55, scale: 1)])
    static let ring = PoseTrack(curve: .css(0.1, 0.6, 0.3, 1), [
        .init(5.04, opacity: 0, scale: 0.6), .init(5.08, opacity: 0.95, scale: 0.6), .init(6.85, opacity: 0, scale: 7),
    ])
    static let flare = PoseTrack(curve: .css(0.2, 0.8, 0.3, 1), [
        .init(5.05, opacity: 0, scale: 0), .init(5.17, scale: 1.15), .init(5.75, opacity: 0.9, scale: 0.3),
    ])
    static let bloom = PoseTrack(curve: .css(0.1, 0.7, 0.3, 1), [
        .init(5.04, opacity: 0, scale: 0.2), .init(5.12, opacity: 1, scale: 0.4), .init(6.6, opacity: 0, scale: 1),
    ])

    // MARK: - The sky and the camera

    /// The whole scene comes in a little close and eases back while the star enters (×1.06 → ×1 by 2.6 s, with the sky's own settle).
    static let zoom = PoseTrack(curve: .css(0.16, 1, 0.3, 1), [.init(0, scale: 1.06), .init(2.6, scale: 1)])

    /// The sky darkens a little while the star flies, so it is the brightest thing on the screen, and the explosion's light lifts it again
    /// (`opacity` of the night laid over the sky).
    static let skyDim = PoseTrack(curve: .css(0.4, 0, 0.2, 1), [
        .init(0.4, opacity: 0), .init(1.1, opacity: 0.3), .init(5.0, opacity: 0.3), .init(5.7, opacity: 0),
    ])

    // MARK: - Sparks

    /// The sparks of the explosion on the sixth dot (the words the star skims only ring).
    static let explosionSparks = WelcomeSpark.explosion(start: explosionTime)

    // MARK: - The star

    /// The star's flight (`WelcomeFlight`), for the three words where they are (their marks' centres in the frame): one smooth curve with
    /// no stops. It comes in from the top right, draws the C passing through each dot as it lights, runs the leg over the dim sixth dot,
    /// loops out to the right and dives to the first word, skims from word to word in low arcs, climbs back and crashes into the sixth dot.
    static func starPath(words: [CGPoint]) -> WelcomeFlight {
        let first = words.first ?? CGPoint(x: 80, y: 665)
        let second = words.dropFirst().first ?? CGPoint(x: 194, y: 665)
        let third = words.dropFirst(2).first ?? CGPoint(x: 308, y: 665)
        func over(_ a: CGPoint, _ b: CGPoint, _ dx: Double, _ dy: Double) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2 + dx, y: (a.y + b.y) / 2 + dy)
        }
        let points: [(Double, CGPoint)] = [
            (0.55, CGPoint(x: 430, y: -20)), (0.84, CGPoint(x: 352, y: 98)),
        ] + dots.map { ($0.hit, $0.point) } + [
            (2.25, cue),
            (2.62, over(cue, first, 80, -14)),
            (2.95, first), (3.25, over(first, second, 0, -26)), (3.55, second), (3.85, over(second, third, 0, -26)), (4.15, third),
            (4.6, over(third, cue, 40, 0)),
            (explosionTime, cue),
        ]
        return WelcomeFlight(
            waypoints: points.map { WelcomeFlight.Waypoint(time: $0.0, point: $0.1) }, litAt: 1.0, fadeFrom: explosionTime, goneAt: 5.17
        )
    }

    // MARK: - The shine of the dots

    /// How long each dot takes to brighten and dim again, and where in that it starts: different for each, so the C never pulses as one.
    private static let shinePeriods: [Double] = [1.7, 2.3, 1.9, 2.6, 2.1, 2.8]
    private static let shinePhases: [Double] = [0, 0.4, 0.15, 0.7, 0.55, 0.3]
    /// Every few seconds a dot glints: a short cross of white light.
    private static let glintPeriods: [Double] = [3.1, 3.7, 2.9, 4.3, 3.4, 3.9]
    private static let glintOffsets: [Double] = [0.1, 0.55, 0.3, 0.8, 0.65, 0.2]

    /// How bright a lit dot is at `time` (0...1): nothing before the star reaches it, then it grows in over 0.6 s and keeps breathing.
    /// The sixth dot is index 5 (it lights with the explosion).
    static func shine(of index: Int, lit: Double, at time: Double) -> Double {
        let start = lit + 0.35
        guard time > start else { return 0 }
        let ramp = min(1, (time - start) / 0.6)
        let wave = 0.5 + 0.5 * sin(2 * .pi * ((time - start) / shinePeriods[index] + shinePhases[index]) - .pi / 2)
        return ramp * wave
    }

    /// The glint of a lit dot at `time` (0...1): a quick flash of 0.35 s, once every few seconds, the first one a second after it lit.
    static func glint(of index: Int, lit: Double, at time: Double) -> Double {
        let start = lit + 1
        guard time > start else { return 0 }
        let cycle = (time - start) / glintPeriods[index] + glintOffsets[index]
        let seconds = (cycle - cycle.rounded(.down)) * glintPeriods[index]
        return seconds < 0.35 ? sin(.pi * seconds / 0.35) : 0
    }

    // MARK: - The words

    /// When the star lands on each word.
    static let wordHits: [Double] = [2.95, 3.55, 4.15]

    /// A word's pill: it appears dim at 1.0 s, lifts 5 pt when the star lands on its mark and lights (`y`, `scale`, `opacity`), and stays lit
    /// (`blur` here is how lit it is, 0...1: the mark gold, the words bright).
    static func pill(hit: Double) -> PoseTrack {
        PoseTrack(curve: .cssEaseOut, [
            .init(0.6, opacity: 0, scale: 0.92, y: 6), .init(1.0, opacity: 0.35),
            .init(hit - 0.12, opacity: 0.35, curve: .css(0.2, 0.9, 0.3, 1)),
            .init(hit, opacity: 1, scale: 1.06, y: -5, blur: 1, curve: .css(0.3, 1.3, 0.5, 1)),
            .init(hit + 0.45, opacity: 1, scale: 1, y: 0, blur: 1),
        ])
    }

    /// The gold glow of a pill's mark and edge: it flares when the star lands and settles to a faint one that stays.
    static func pillGlow(hit: Double) -> PoseTrack {
        PoseTrack(curve: .cssEaseOut, [.init(hit - 0.02, opacity: 0), .init(hit, opacity: 1), .init(hit + 1.3, opacity: 0.3)])
    }

    /// The ring that opens around a word the star landed on.
    static func wordRing(hit: Double) -> PoseTrack {
        PoseTrack(curve: .css(0.1, 0.7, 0.3, 1), [
            .init(hit - 0.01, opacity: 0, scale: 0.5), .init(hit, opacity: 0.8, scale: 0.5), .init(hit + 0.5, opacity: 0, scale: 3),
        ])
    }

    // MARK: - The wordmark

    /// "CUE STUDIO": the letters leave from the middle outward (S and T at 5.24 s, C and O at 5.52 s), each stretched ×3.4 across and
    /// blurred, settling in 0.54 s; the tracking closes from 1 em to 0.34 em; a yellow glint runs over them (0.12 s up, 0.33 s down, 0.05 s apart).
    struct Letter: Sendable {
        let character: Character
        /// 0 → 1 as it settles.
        let track: PoseTrack
        /// 0 → 1 → 0, the yellow of the glint.
        let glow: PoseTrack

        init(character: Character, start: Double, glint: Double) {
            self.character = character
            track = PoseTrack(curve: .css(0.12, 0.8, 0.2, 1), [
                .init(0, opacity: 0, scaleX: 3.4, scaleY: 0.35, blur: 8), .init(start, opacity: 0, scaleX: 3.4, scaleY: 0.35, blur: 8),
                .init(start + 0.54), .init(1000),
            ])
            glow = PoseTrack([.init(glint - 0.12, opacity: 0), .init(glint, opacity: 1), .init(glint + 0.33, opacity: 0)])
        }
    }

    static let letters: [Letter] = {
        let starts: [Double] = [5.52, 5.45, 5.38, 5.24, 5.24, 5.31, 5.38, 5.45, 5.52]
        let glints: [Double] = [6.42, 6.47, 6.52, 6.62, 6.67, 6.72, 6.77, 6.82, 6.87]
        return Array("CUESTUDIO").enumerated().map { Letter(character: $1, start: starts[$0], glint: glints[$0]) }
    }()

    /// The tracking of the wordmark, in em: 1 until 5.15 s, 0.34 at 6.2 s.
    static let tracking = PoseTrack(curve: .css(0.16, 1, 0.3, 1), [.init(5.15, scale: 1), .init(6.2, scale: 0.34)])

    // MARK: - The title and the rest

    /// A word of the title rising out of the blur: the first at 5.5 s, 85 ms apart, each taking 0.85 s.
    static func titleWord(_ index: Int) -> PoseTrack {
        let start = 5.5 + Double(index) * 0.085
        return PoseTrack(curve: .css(0.16, 1, 0.3, 1), [.init(start, opacity: 0, y: 16, blur: 10), .init(start + 0.85)])
    }

    /// The gold light that runs over the title once it has landed, word after word (7.05 s on, 0.55 s from the first word to the last): each
    /// word warms in 0.16 s and cools in 0.5 s (`opacity`, 0...1).
    static func titleGlint(_ index: Int, of count: Int) -> PoseTrack {
        let start = 7.05 + Double(index) * min(0.08, 0.55 / Double(max(1, count - 1)))
        return PoseTrack(curve: .css(0.4, 0, 0.2, 1), [.init(start, opacity: 0), .init(start + 0.16, opacity: 1), .init(start + 0.66, opacity: 0)])
    }

    /// The line under the title (6.55–7.45 s) and the yellow button (6.95–7.75 s).
    static let subtitle = PoseTrack(curve: .css(0.16, 1, 0.3, 1), [.init(6.55, opacity: 0, y: 10), .init(7.45)])
    static let primaryButton = PoseTrack(curve: .css(0.16, 1, 0.3, 1), [.init(6.95, opacity: 0, y: 22), .init(7.75)])

    // MARK: - Haptics

    enum Beat: Sendable { case letter, word, explosion }

    /// How many beats the story has passed at `time`: the haptic of the latest (`orderedBeats[passed - 1]`) plays when this grows.
    static func beatsPassed(at time: Double) -> Int {
        beats.filter { $0.time <= time }.count
    }

    /// What the hand feels and when: a hum with a tap on each dot while the star draws the C (one pattern, `HapticPatterns.welcomeC`, from
    /// the first dot), a light tap on each word, a success on the explosion.
    static let beats: [(time: Double, beat: Beat)] =
        [(dots[0].hit, Beat.letter)] + wordHits.map { ($0, Beat.word) } + [(explosionTime, Beat.explosion)]

    /// The beats in the order they come.
    static let orderedBeats = beats.sorted { $0.time < $1.time }
}
