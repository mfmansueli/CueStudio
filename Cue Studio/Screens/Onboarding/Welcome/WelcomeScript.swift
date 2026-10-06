//
//  WelcomeScript.swift
//  Cue Studio
//

import SwiftUI

/// The 1.1 opening, written as the board has it (09 §12, `motion/README.md`): in a 390 × 844 frame a star comes in from the top right,
/// lights five dots that draw the C, draws the leg without lighting the sixth, arcs down to three words, returns and explodes into the
/// sixth dot; then the wordmark, the title and the buttons arrive. Every moment is a `PoseTrack`, so the scene is a function of the second
/// it is drawn at, and holds still once the last one is over.
enum WelcomeScript {
    /// The frame of the board; the scene is laid out in it, centred on the screen.
    static let frame = CGSize(width: 390, height: 844)
    /// Everything is in place (the buttons land at 7.75–7.9 s).
    static let finalTime = 7.9

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

    /// The star becomes the sixth dot: the core swells ×2.2 and settles, two rings open, a yellow cross opens and settles small.
    static let core = PoseTrack(curve: .css(0.3, 1.3, 0.5, 1), [.init(5.0, scale: 0), .init(5.15, scale: 2.2), .init(5.55, scale: 1)])
    static let ring = PoseTrack(curve: .css(0.1, 0.6, 0.3, 1), [
        .init(5.04, opacity: 0, scale: 0.6), .init(5.08, opacity: 0.95, scale: 0.6), .init(6.85, opacity: 0, scale: 7),
    ])
    static let secondRing = PoseTrack(curve: .css(0.1, 0.6, 0.3, 1), [
        .init(5.2, opacity: 0, scale: 0.6), .init(5.23, opacity: 0.7, scale: 0.6), .init(7.05, opacity: 0, scale: 5.5),
    ])
    static let flare = PoseTrack(curve: .css(0.2, 0.8, 0.3, 1), [
        .init(5.05, opacity: 0, scale: 0), .init(5.17, scale: 1.15), .init(5.75, opacity: 0.9, scale: 0.3),
    ])

    // MARK: - The dust between the dots

    /// A four-point speck on the line between two dots: it blinks open at `start + 0.08`, turns and goes out by `start + 0.9`.
    struct Dust: Sendable {
        let point: CGPoint
        let size: CGFloat
        let track: PoseTrack

        init(point: CGPoint, size: CGFloat, start: Double) {
            self.point = point
            self.size = size
            track = PoseTrack([
                .init(start, opacity: 0, scale: 0), .init(start + 0.08, scale: 1.3, rotation: 20),
                .init(start + 0.5, opacity: 0.8, scale: 0.7, rotation: 60), .init(start + 0.9, opacity: 0, scale: 0, rotation: 90),
            ])
        }
    }

    static let dust: [Dust] = [
        Dust(point: CGPoint(x: 221.9, y: 177.4), size: 12, start: 1.17), Dust(point: CGPoint(x: 198.2, y: 174.4), size: 9, start: 1.24),
        Dust(point: CGPoint(x: 164.5, y: 186.5), size: 12, start: 1.37), Dust(point: CGPoint(x: 148.2, y: 202.8), size: 9, start: 1.44),
        Dust(point: CGPoint(x: 136.3, y: 234.5), size: 12, start: 1.57), Dust(point: CGPoint(x: 137.8, y: 255.2), size: 9, start: 1.64),
        Dust(point: CGPoint(x: 154.8, y: 283.9), size: 12, start: 1.77), Dust(point: CGPoint(x: 172.6, y: 297.2), size: 9, start: 1.84),
        Dust(point: CGPoint(x: 206.8, y: 305.4), size: 12, start: 2.02), Dust(point: CGPoint(x: 229.0, y: 302.4), size: 9, start: 2.14),
    ]

    // MARK: - Sparks

    /// The sparks of each word the star lands on, and of the explosion on the sixth dot.
    static let wordSparks: [[WelcomeSpark]] = wordHits.map { WelcomeSpark.word(start: $0) }
    static let explosionSparks = WelcomeSpark.explosion(start: explosionTime)

    // MARK: - The star

    /// The star and its three followers, from the largest to the smallest: how late each is, how big, how bright and what colour.
    static let trail: [(delay: Double, size: CGFloat, opacity: Double, color: Color)] = [
        (0, 9, 1, .white), (0.08, 6.5, 0.6, Palette.Universe.starCream), (0.14, 5, 0.4, Palette.Universe.starWarm), (0.2, 4, 0.25, Palette.Universe.starGold),
    ]

    /// Where the star is (`x`, `y`) and how visible (`opacity`), for the three words it visits: at their centres (frame coordinates).
    /// Between two dots it takes a small arc; to and from the words a bigger one, bending the way the board has it.
    static func starPath(words: [CGPoint]) -> PoseTrack {
        let hop = UnitCurve.css(0.5, 0, 0.9, 0.7)
        let fall = UnitCurve.css(0.1, 0.3, 0.5, 1)
        let first = words.first ?? CGPoint(x: 80, y: 665)
        let second = words.dropFirst().first ?? CGPoint(x: 194, y: 665)
        let third = words.dropFirst(2).first ?? CGPoint(x: 308, y: 665)
        func over(_ a: CGPoint, _ b: CGPoint, _ dx: Double, _ dy: Double) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2 + dx, y: (a.y + b.y) / 2 + dy)
        }
        let bounce1 = over(first, second, 0, -30)
        let bounce2 = over(second, third, 0, -30)
        let dive = over(cue, first, 75, -10)
        let climb = over(third, cue, 34, 0)
        return PoseTrack([
            .init(0, opacity: 0, x: 430, y: -20), .init(0.55, opacity: 0, x: 430, y: -20, curve: .css(0.2, 0.7, 0.3, 1)),
            .init(1.10, x: 243, y: 180), .init(1.13, x: 243, y: 180, curve: hop), .init(1.215, x: 215.35, y: 169.29), .init(1.30, x: 179, y: 172),
            .init(1.33, x: 179, y: 172, curve: hop), .init(1.415, x: 153.27, y: 186.92), .init(1.50, x: 135, y: 216),
            .init(1.53, x: 135, y: 216, curve: hop), .init(1.615, x: 129.47, y: 246.7), .init(1.70, x: 139, y: 272),
            .init(1.73, x: 139, y: 272, curve: hop), .init(1.815, x: 161.3, y: 297.82), .init(1.90, x: 187, y: 308),
            .init(1.94, x: 187, y: 308, curve: hop), .init(2.095, x: 217, y: 310), .init(2.25, x: 247, y: 300),
            .init(2.60, x: dive.x, y: dive.y, curve: fall), .init(2.95, x: first.x, y: first.y),
            .init(3.05, x: first.x, y: first.y, curve: hop), .init(3.30, x: bounce1.x, y: bounce1.y, curve: fall), .init(3.55, x: second.x, y: second.y),
            .init(3.65, x: second.x, y: second.y, curve: hop), .init(3.90, x: bounce2.x, y: bounce2.y, curve: fall), .init(4.15, x: third.x, y: third.y),
            .init(4.25, x: third.x, y: third.y, curve: hop), .init(4.65, x: climb.x, y: climb.y, curve: fall), .init(5.05, x: 247, y: 300),
            .init(5.17, opacity: 0, x: 247, y: 300),
        ])
    }

    // MARK: - The words

    /// When the star lands on each word.
    static let wordHits: [Double] = [2.95, 3.55, 4.15]

    /// A word's pill: it appears dim at 1.0 s, jumps 12 pt and lights yellow when the star lands (`y`, `scale`, `opacity`), and goes back to
    /// its colours (`blur` here is how lit it is, 0...1).
    static func pill(hit: Double) -> PoseTrack {
        PoseTrack(curve: .cssEaseOut, [
            .init(0.6, opacity: 0, scale: 0.85, y: 8), .init(1.0, opacity: 0.35),
            .init(hit - 0.12, opacity: 0.35, curve: .css(0.2, 0.9, 0.3, 1)),
            .init(hit, opacity: 1, scale: 1.1, y: -12, blur: 1, curve: .css(0.5, 0, 0.8, 0.6)),
            .init(hit + 0.22, opacity: 1, scale: 1, y: 0, blur: 0.7), .init(hit + 1.3, opacity: 1, blur: 0),
        ])
    }

    /// The oval of light that crosses a word once the star is on it, left to right, in 0.44 s (0 before, 1 after).
    static func sweep(hit: Double) -> PoseTrack {
        PoseTrack(curve: .css(0.5, 0, 0.2, 1), [
            .init(hit + 0.02, opacity: 0, scale: 0), .init(hit + 0.06, opacity: 1, scale: 0), .init(hit + 0.5, opacity: 1, scale: 1),
            .init(hit + 0.52, opacity: 0, scale: 1),
        ])
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

    /// The line under the title (6.55–7.45 s), the yellow button (6.95–7.75 s) and the quiet one (7.1–7.9 s).
    static let subtitle = PoseTrack(curve: .css(0.16, 1, 0.3, 1), [.init(6.55, opacity: 0, y: 10), .init(7.45)])
    static let primaryButton = PoseTrack(curve: .css(0.16, 1, 0.3, 1), [.init(6.95, opacity: 0, y: 22), .init(7.75)])
    static let secondaryButton = PoseTrack(curve: .css(0.16, 1, 0.3, 1), [.init(7.1, opacity: 0, y: 22), .init(7.9)])

    // MARK: - Haptics

    enum Beat: Sendable { case dot, word, explosion }

    /// What the hand feels and when: a soft tap on each of the five dots, a light one on each word, a success on the explosion.
    static let beats: [(time: Double, beat: Beat)] =
        dots.map { ($0.hit, Beat.dot) } + wordHits.map { ($0, Beat.word) } + [(explosionTime, Beat.explosion)]
}
