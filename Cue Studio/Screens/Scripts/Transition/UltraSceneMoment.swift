//
//  UltraSceneMoment.swift
//  Cue Studio
//

import Foundation

/// One moment of the scene round Ultra AI's star (`UltraWaitScene`), worked out from what the meter knows: the chapter shown, how far each
/// chapter's motion has come, the sparks of the words, the comets of a long chapter and the finish. Apart from the drawing, so it is tested.
struct UltraSceneMoment {
    let time: TimeInterval
    let timeline: UltraWaitTimeline
    /// The chapter shown; nil before the draft began.
    let chapter: Int?
    /// Every step of words so far, in order, and when the draft's arrived (each a new star of the galaxy).
    let arrivals: [WritingArrival]
    let draftArrivals: [TimeInterval]
    /// The finish: the moons and the galaxy falling into the star, 0…1 up to the flash.
    let fall: Double
    /// The wave of light after the flash, 0…1; nil before it and once it has gone.
    let wave: Double?
    /// The beam of the pass that checks the claims: how strong, and where it points (radians round the galaxy).
    let beam: Double
    let beamAngle: Double
    /// How far the polish has warmed the galaxy to gold, 0…1 (from the inside out).
    let warmth: Double
    /// How bright the galaxy is: it charges with the pass on now, 0…1, and gives its light to the moon as the next chapter starts (it eases
    /// back down over that chapter's entry, never in a jump).
    let charge: Double
    /// A comet crossing over the galaxy, which flares under it, 0…1.
    let flare: Double
    /// When the comets now crossing set off.
    let comets: [TimeInterval]

    /// The wave's time after the flash.
    static let waveTime: TimeInterval = 0.7
    /// The beam goes round the galaxy once in this many seconds.
    static let sweep: TimeInterval = 2.6

    /// - Parameters:
    ///   - finish: when the finish began (the script is there), or nil while it is written.
    ///   - pass: the pass on now (`WritingProgressMeter.pass`), and how far it looks (`passFraction`).
    init(
        time: TimeInterval, finish: TimeInterval?, passStarts: [TimeInterval], count: Int, arrivals: [WritingArrival], pass: Int?,
        passShown: Double
    ) {
        self.time = time
        timeline = UltraWaitTimeline(passStarts: passStarts, count: count)
        chapter = timeline.chapter(at: time)
        self.arrivals = arrivals
        draftArrivals = arrivals.filter { $0.pass == 0 }.map(\.time)
        if let finish {
            fall = min(1, max(0, (time - finish) / IdeaTransitionService.ultraFlashTime))
            let after = (time - finish - IdeaTransitionService.ultraFlashTime) / Self.waveTime
            wave = after >= 0 && after < 1 ? after : nil
        } else {
            fall = 0
            wave = nil
        }
        // The claims are checked in the middle pass of three or, with two, in the polish, which corrects them as it applies the voice (the
        // app's flow since 04/11/2026, `UltraFlow.standard`): its beam sweeps round the galaxy while it warms, until the finish.
        let check = 1
        if timeline.count > 1, timeline.starts.indices.contains(check) {
            let over = timeline.count > 2 ? timeline.entry(of: check + 1, at: time) : fall
            beam = timeline.entry(of: check, at: time) * (1 - over)
            beamAngle = (time - timeline.starts[check]) * 2 * .pi / Self.sweep
        } else {
            beam = 0
            beamAngle = 0
        }
        let voice = timeline.count - 1
        let polish = voice > 0 && pass == voice ? passShown * timeline.entry(of: voice, at: time) : 0
        warmth = max(polish, fall)
        var handedOver = 0.0
        if let chapter, chapter > 0 { handedOver = 1 - timeline.entry(of: chapter, at: time) }
        charge = max(passShown, handedOver, fall)
        if let chapter {
            let crossing = UltraWaitTimeline.cometFlight / 2
            comets = timeline.comets(in: chapter, until: time).filter { time - $0 < UltraWaitTimeline.cometFlight }
            flare = comets.map { max(0, 1 - abs(time - $0 - crossing) / 0.7) }.max() ?? 0
        } else {
            comets = []
            flare = 0
        }
    }
}
