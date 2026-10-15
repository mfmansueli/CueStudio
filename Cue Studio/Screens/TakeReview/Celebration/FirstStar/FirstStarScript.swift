//
//  FirstStarScript.swift
//  Cue Studio
//

import SwiftUI

/// The first star (1.7) as a function of time, with the keyframes of the board (`1.7_Your-first-star`, 8 s): the take shows "✓ SAVED", folds into light
/// at 1.55 s, a comet carries it along a curve to the star's place (1.6–2.9 s), the star lights with a burst, two rings and a cross of light (2.9 s), a line
/// draws from "YOU" (3.3–4.1 s) and the words come in. The board loops; the app plays to 7.5 s and holds, and the orbits keep turning.
nonisolated enum FirstStarScript {
    static let duration = 8.0
    /// Where the board shows everything at rest (93.75%), before it fades out to loop.
    static let hold = 7.5
    /// When the star lights (36.875%): the haptic.
    static let landing = 2.95

    // MARK: - Where things are (the board's 390 × 844 frame)

    static let core = CGPoint(x: 195, y: 262)
    static let star = CGPoint(x: 256, y: 188)
    static let routeStart = CGPoint(x: 69, y: 300)
    static let routeControl1 = CGPoint(x: 90, y: 250)
    static let routeControl2 = CGPoint(x: 180, y: 240)
    static let tilt = Angle.degrees(-12)
    static let flatten = 0.42

    enum Tone {
        case pink, mint, warm
    }

    struct Orbit {
        let radius: Double
        let planet: Double
        /// Seconds for one turn.
        let period: Double
        /// The board starts the planet this many seconds into its turn.
        let head: Double
        let tone: Tone
    }

    static let orbits = [
        Orbit(radius: 146, planet: 16, period: 30, head: 10, tone: .pink),
        Orbit(radius: 108, planet: 14, period: 22, head: 4, tone: .mint),
        Orbit(radius: 70, planet: 18, period: 14, head: 0, tone: .warm),
    ]

    /// A planet's place on the screen at `time`: the ellipse is squashed to 42% and tilted 12°, and the planet itself stays round.
    static func planet(_ orbit: Orbit, at time: Double) -> CGPoint {
        let angle = (time + orbit.head) / orbit.period * 2 * .pi
        return ellipsePoint(radius: orbit.radius, angle: angle)
    }

    static func ellipsePoint(radius: Double, angle: Double) -> CGPoint {
        let x = radius * cos(angle)
        let y = radius * sin(angle) * flatten
        let tilt = tilt.radians
        return CGPoint(x: core.x + x * cos(tilt) - y * sin(tilt), y: core.y + x * sin(tilt) + y * cos(tilt))
    }

    /// 0 → 1 and back every `period` seconds, eased (the board's `ease-in-out infinite`).
    static func breath(at time: Double, period: Double) -> Double { (1 - cos(time / period * 2 * .pi)) / 2 }

    // MARK: - The take

    private static let fold = UnitCurve.css(0.6, 0, 0.3, 1)
    private static let thumbOpacity = Keyframes([(0, 0), (5.625, 1), (19.375, 1), (20.25, 0), (100, 0)], curve: fold, duration: duration)
    private static let thumbScale = Keyframes([(0, 0.9), (5.625, 1), (12.5, 1.05), (19.375, 0.06), (20.25, 0.05), (100, 0.05)], curve: fold, duration: duration)
    private static let thumbBright = Keyframes([(0, 1), (12.5, 1), (19.375, 3), (100, 3)], curve: fold, duration: duration)
    private static let thumbRadius = Keyframes([(0, 14), (12.5, 14), (19.375, 60), (100, 60)], curve: fold, duration: duration)
    private static let savedOpacity = Keyframes(
        [(0, 0), (4.375, 0), (7.5, 1), (13.125, 1), (15.625, 0), (100, 0)], curve: .css(0, 0, 0.58, 1), duration: duration
    )
    private static let glowOpacity = Keyframes([(0, 0), (15, 0), (18.75, 1), (21.875, 0), (100, 0)], curve: .css(0, 0, 0.58, 1), duration: duration)
    private static let glowScale = Keyframes([(0, 0.2), (15, 0.2), (18.75, 1.3), (21.875, 0.6), (100, 0.6)], curve: .css(0, 0, 0.58, 1), duration: duration)

    static func take(at time: Double) -> (opacity: Double, scale: Double, brightness: Double, radius: Double) {
        (thumbOpacity.value(at: time), thumbScale.value(at: time), thumbBright.value(at: time), thumbRadius.value(at: time))
    }

    /// "✓ SAVED" on the take.
    static func saved(at time: Double) -> (opacity: Double, lift: Double) {
        let opacity = savedOpacity.value(at: time)
        return (opacity, 4 * (1 - min(1, opacity)))
    }

    /// The flash where the take folds.
    static func glow(at time: Double) -> (opacity: Double, scale: Double) { (glowOpacity.value(at: time), glowScale.value(at: time)) }

    // MARK: - The comet

    private static let travel = Keyframes([(0, 0), (20, 0), (36.25, 1), (100, 1)], curve: .css(0.55, 0, 0.3, 1), duration: duration)
    private static let trailOpacity = Keyframes([(0, 0), (20, 0), (20.375, 1), (36.25, 1), (37.5, 0), (100, 0)], duration: duration)
    private static let orbOpacity = Keyframes([(0, 0), (17.5, 0), (17.875, 1), (36.25, 1), (37.5, 0), (100, 0)], duration: duration)

    /// How far along the route the comet is (0 → 1), how visible its orb is, and how visible its head is while it travels.
    static func comet(at time: Double) -> (head: Double, orb: Double, travelling: Double) {
        (travel.value(at: time), orbOpacity.value(at: time), trailOpacity.value(at: time))
    }

    /// The point `fraction` of the way along the comet's route.
    static func route(_ fraction: Double) -> CGPoint {
        let t = min(1, max(0, fraction))
        let u = 1 - t
        let x = u * u * u * routeStart.x + 3 * u * u * t * routeControl1.x + 3 * u * t * t * routeControl2.x + t * t * t * star.x
        let y = u * u * u * routeStart.y + 3 * u * u * t * routeControl1.y + 3 * u * t * t * routeControl2.y + t * t * t * star.y
        return CGPoint(x: x, y: y)
    }

    struct Sparkle {
        let origin: CGPoint
        let start: Double
    }

    static let sparkles = [
        Sparkle(origin: CGPoint(x: 104, y: 264), start: 25), Sparkle(origin: CGPoint(x: 152, y: 240), start: 28.75),
        Sparkle(origin: CGPoint(x: 205, y: 217), start: 32.5),
    ]

    /// A sparkle the comet leaves: it appears at full size and sinks and shrinks as it fades.
    static func sparkle(_ item: Sparkle, at time: Double) -> (opacity: Double, scale: Double, drop: Double) {
        let curve = UnitCurve.css(0, 0, 0.58, 1)
        let opacity = Keyframes([(0, 0), (item.start, 0), (item.start + 1.25, 1), (item.start + 13.75, 0), (100, 0)], curve: curve, duration: duration)
        let scale = Keyframes([(0, 0.4), (item.start, 0.4), (item.start + 1.25, 1), (item.start + 13.75, 0.5), (100, 0.5)], curve: curve, duration: duration)
        let drop = Keyframes([(0, 0), (item.start + 1.25, 0), (item.start + 13.75, 10), (100, 10)], curve: curve, duration: duration)
        return (opacity.value(at: time), scale.value(at: time), drop.value(at: time))
    }

    // MARK: - The star

    private static let lineDraw = Keyframes([(0, 0), (41.25, 0), (51.25, 1), (100, 1)], curve: .css(0.45, 0, 0.25, 1), duration: duration)
    private static let crossScale = Keyframes([(0, 0), (36.5, 0), (38.75, 1), (47.75, 0.28), (100, 0.28)], curve: .css(0.2, 0.8, 0.3, 1), duration: duration)
    private static let crossOpacity = Keyframes([(0, 0), (36.5, 0), (38.75, 1), (47.75, 0.9), (100, 0.9)], curve: .css(0.2, 0.8, 0.3, 1), duration: duration)
    private static let starScale = Keyframes([(0, 0.2), (36.25, 0.2), (38.75, 1.8), (43.75, 1), (100, 1)], curve: .css(0.3, 1.3, 0.5, 1), duration: duration)
    private static let starOpacity = Keyframes([(0, 0), (36.25, 0), (38.75, 1), (100, 1)], curve: .css(0.3, 1.3, 0.5, 1), duration: duration)
    private static let ringCurve = UnitCurve.css(0.1, 0.6, 0.3, 1)

    /// The line from YOU to the star, drawn 0 → 1.
    static func line(at time: Double) -> Double { lineDraw.value(at: time) }

    /// The cross of light on the star: it flares and settles small.
    static func cross(at time: Double) -> (scale: Double, opacity: Double) { (crossScale.value(at: time), crossOpacity.value(at: time)) }

    static func starPose(at time: Double) -> (scale: Double, opacity: Double) { (starScale.value(at: time), starOpacity.value(at: time)) }

    /// The two rings that go out of the star: radius in points (of a 40 pt box) and opacity, nil when not there.
    static func rings(at time: Double) -> [(scale: Double, opacity: Double, width: Double, isGold: Bool)] {
        let first = Keyframes([(0, 0.3), (36.25, 0.3), (36.875, 0.4), (48.75, 3.2), (100, 3.2)], curve: ringCurve, duration: duration)
        let firstOpacity = Keyframes([(0, 0), (36.25, 0), (36.875, 0.95), (48.75, 0), (100, 0)], curve: ringCurve, duration: duration)
        let second = Keyframes([(0, 0.3), (38.5, 0.3), (39.125, 0.4), (51, 2.4), (100, 2.4)], curve: ringCurve, duration: duration)
        let secondOpacity = Keyframes([(0, 0), (38.5, 0), (39.125, 0.95), (51, 0), (100, 0)], curve: ringCurve, duration: duration)
        return [
            (first.value(at: time), firstOpacity.value(at: time), 1.5, true),
            (second.value(at: time), secondOpacity.value(at: time), 1, false),
        ]
    }

    /// The ten specks that fly out of the star as it lights: where they end (from the star), as the board lists them.
    static let burst: [CGPoint] = [
        CGPoint(x: 29.7, y: 4.2), CGPoint(x: 27.3, y: 26.4), CGPoint(x: 8, y: 45.3), CGPoint(x: -13.2, y: 27), CGPoint(x: -33.6, y: 17.8),
        CGPoint(x: -45.6, y: -6.4), CGPoint(x: -21.6, y: -20.8), CGPoint(x: -6.6, y: -37.4), CGPoint(x: 20.2, y: -41.3), CGPoint(x: 26.5, y: -14.1),
    ]

    static func burst(at time: Double) -> (progress: Double, opacity: Double) {
        let curve = UnitCurve.css(0.1, 0.7, 0.3, 1)
        let move = Keyframes([(0, 0), (36.875, 0), (46.25, 1), (100, 1)], curve: curve, duration: duration)
        let opacity = Keyframes([(0, 0), (36.25, 0), (36.875, 1), (46.25, 0), (100, 0)], curve: curve, duration: duration)
        return (move.value(at: time), opacity.value(at: time))
    }

    struct Dust {
        let origin: CGPoint
        let start: Double
        let fall: Double
    }

    /// The specks that sink from the star while the words come in.
    static let dust = [
        Dust(origin: CGPoint(x: 254, y: 190), start: 57.331, fall: 47), Dust(origin: CGPoint(x: 218, y: 194), start: 41.616, fall: 85),
        Dust(origin: CGPoint(x: 261, y: 197), start: 47.58, fall: 42), Dust(origin: CGPoint(x: 273, y: 193), start: 43.143, fall: 76),
        Dust(origin: CGPoint(x: 236, y: 182), start: 58.477, fall: 65), Dust(origin: CGPoint(x: 264, y: 202), start: 54.922, fall: 59),
        Dust(origin: CGPoint(x: 225, y: 188), start: 54.514, fall: 74),
    ]

    static func dust(_ item: Dust, at time: Double) -> (opacity: Double, drop: Double) {
        let opacity = Keyframes([(0, 0), (item.start, 0), (item.start + 3.75, 0.9), (item.start + 32.5, 0), (100, 0)], duration: duration)
        let drop = Keyframes([(0, 0), (item.start, 0), (item.start + 3.75, 6), (item.start + 32.5, item.fall), (100, item.fall)], duration: duration)
        return (opacity.value(at: time), drop.value(at: time))
    }

    /// "FIRST TAKE · TODAY" above the star.
    static func label(at time: Double) -> (opacity: Double, lift: Double) {
        let opacity = Keyframes([(0, 0), (46.25, 0), (52.5, 1), (100, 1)], curve: .css(0.2, 0.7, 0.2, 1), duration: duration).value(at: time)
        return (opacity, 4 * (1 - opacity))
    }

    // MARK: - The words

    private static let rise = UnitCurve.css(0.16, 1, 0.3, 1)

    /// Something that rises into place: how far it has come (0 → 1) from `start` percent over `length` percent of the cycle.
    static func arrival(startingAt start: Double, length: Double, at time: Double) -> Double {
        Keyframes([(0, 0), (start, 0), (start + length, 1), (100, 1)], curve: rise, duration: duration).value(at: time)
    }

    static let chapterStart = (percent: 44.375, length: 7.5)
    /// The words of the title come in 1.125% of the cycle apart, from 46.25%.
    static func wordStart(_ index: Int) -> Double { 46.25 + 1.125 * Double(index) }
    static let subtitleStart = 55.625
    static let studioStart = 59.375
    static let editStart = 61.25

    /// The gold light that crosses the title once, after its last word (0 → 1 across it, 5.35–6.35 s).
    static func titleSweep(at time: Double) -> Double {
        Keyframes([(0, 0), (seconds(5.35), 0), (seconds(6.35), 1), (100, 1)], curve: .css(0.4, 0, 0.2, 1), duration: duration).value(at: time)
    }

    /// The shine across "Explore Cue" (77.5–87.5% of the cycle).
    static func shine(at time: Double) -> Double {
        Keyframes([(0, 0), (77.5, 0), (87.5, 1), (100, 1)], curve: .css(0.4, 0, 0.2, 1), duration: duration).value(at: time)
    }

    // MARK: - The finish (the owner's pass, on top of the board)

    /// A second of the story as a percent of the cycle, for the keyframes written in seconds.
    private static func seconds(_ value: Double) -> Double { value / duration * 100 }

    /// The light that runs once round the take's edge before it folds (the end of the lit stretch, 0 → 1 round the card, 0.95–1.45 s).
    static func rimLight(at time: Double) -> (end: Double, opacity: Double) {
        let end = Keyframes([(0, 0), (seconds(0.95), 0), (seconds(1.45), 1), (100, 1)], curve: .css(0.5, 0, 0.5, 1), duration: duration)
        let opacity = Keyframes(
            [(0, 0), (seconds(0.95), 0), (seconds(1.05), 1), (seconds(1.4), 1), (seconds(1.55), 0), (100, 0)], duration: duration
        )
        return (end.value(at: time), opacity.value(at: time))
    }

    /// Where the take becomes light: a horizontal flare like a cinema lens's (its half width, 0 → 120 pt) and a shockwave ring (its radius).
    static func fold(at time: Double) -> (flare: Double, flareOpacity: Double, wave: Double, waveOpacity: Double) {
        let curve = UnitCurve.css(0.1, 0.7, 0.3, 1)
        let flare = Keyframes([(0, 0), (seconds(1.45), 0), (seconds(1.7), 120), (seconds(2.2), 150), (100, 150)], curve: curve, duration: duration)
        let flareOpacity = Keyframes(
            [(0, 0), (seconds(1.45), 0), (seconds(1.55), 1), (seconds(2.2), 0), (100, 0)], curve: .css(0, 0, 0.58, 1), duration: duration
        )
        let wave = Keyframes([(0, 6), (seconds(1.5), 6), (seconds(2.2), 74), (100, 74)], curve: curve, duration: duration)
        let waveOpacity = Keyframes([(0, 0), (seconds(1.5), 0), (seconds(1.53), 0.8), (seconds(2.2), 0), (100, 0)], duration: duration)
        return (flare.value(at: time), flareOpacity.value(at: time), wave.value(at: time), waveOpacity.value(at: time))
    }

    /// Where the comet's head is at `time` and how visible, for its trail (`StarRibbon`).
    static func cometHead(at time: Double) -> (point: CGPoint, opacity: Double) {
        let comet = comet(at: time)
        return (route(comet.head), comet.travelling)
    }

    /// The light taps the hand feels while the comet flies, closer and stronger as it nears the star (the last is the landing's success).
    static let flightTaps: [(second: Double, isStrong: Bool)] = [(1.75, false), (2.2, false), (2.5, false), (2.7, true), (2.83, true)]

    /// How lit the universe is: it dims a little just before the star lights (the breath before it), and comes back as it does.
    static func universeLight(at time: Double) -> Double {
        Keyframes(
            [(0, 1), (seconds(2.7), 1), (seconds(2.9), 0.55), (seconds(3.0), 0.55), (seconds(3.5), 1), (100, 1)], curve: .css(0.4, 0, 0.2, 1),
            duration: duration
        ).value(at: time)
    }

    /// The flash as the star lights: a wide bloom of white and gold (radius, opacity).
    static func bloom(at time: Double) -> (radius: Double, opacity: Double) {
        let radius = Keyframes(
            [(0, 10), (seconds(2.9), 10), (seconds(3.05), 95), (seconds(3.8), 120), (100, 120)], curve: .css(0.1, 0.7, 0.3, 1), duration: duration
        )
        let opacity = Keyframes(
            [(0, 0), (seconds(2.9), 0), (seconds(2.98), 0.9), (seconds(3.8), 0), (100, 0)], curve: .css(0, 0, 0.58, 1), duration: duration
        )
        return (radius.value(at: time), opacity.value(at: time))
    }

    /// The wave of light that crosses the orbits outward once the star is lit, and the pulse of YOU with it: how much more light an orbit of
    /// `radius` has (0...1).
    static func orbitWave(radius: Double, at time: Double) -> Double {
        let start = 3.0 + (radius - 70) / 76 * 0.32
        return Keyframes(
            [(0, 0), (seconds(start), 0), (seconds(start + 0.12), 1), (seconds(start + 0.8), 0), (100, 0)], curve: .css(0, 0, 0.58, 1),
            duration: duration
        ).value(at: time)
    }

    static func youPulse(at time: Double) -> Double {
        Keyframes([(0, 0), (seconds(2.98), 0), (seconds(3.1), 1), (seconds(3.9), 0), (100, 0)], curve: .css(0, 0, 0.58, 1), duration: duration)
            .value(at: time)
    }

    /// The camera's slow push into the universe over the story (×1 → ×1.04), eased at both ends.
    static func push(at time: Double) -> Double {
        1 + 0.04 * Keyframes([(0, 0), (seconds(hold), 1), (100, 1)], curve: .css(0.45, 0, 0.55, 1), duration: duration).value(at: time)
    }

    /// The lit star's life once the story rests: how bright it breathes is `breath`; every few seconds it glints (0...1, a 0.4 s flash).
    static func starGlint(at world: Double) -> Double {
        let start = landing + 1.6
        guard world > start else { return 0 }
        let period = 3.4
        let into = (world - start).truncatingRemainder(dividingBy: period)
        return into < 0.4 ? sin(.pi * into / 0.4) : 0
    }

    /// A shooting star that crosses the sky above the universe once the story rests, every 9 s from 8.5 s: where its head is and how visible
    /// (nil between two).
    static func shootingStar(at world: Double) -> (point: CGPoint, opacity: Double)? {
        let first = 8.5
        let period = 9.0
        let flight = 0.9
        guard world >= first else { return nil }
        let into = (world - first).truncatingRemainder(dividingBy: period)
        guard into <= flight else { return nil }
        let progress = UnitCurve.css(0.3, 0, 0.7, 1).value(at: into / flight)
        let from = CGPoint(x: 400, y: 36)
        let to = CGPoint(x: 120, y: 124)
        let opacity = min(1, into / 0.15, (flight - into) / 0.25)
        return (CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress), max(0, opacity))
    }
}
