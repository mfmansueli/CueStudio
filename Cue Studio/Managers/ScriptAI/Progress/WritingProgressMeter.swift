//
//  WritingProgressMeter.swift
//  Cue Studio
//

import Foundation

/// The percentage of one script being written: the writer tells it what it is doing (`ScriptWritingEvent`), the star and the page's pill read
/// it (`WritingProgressLabel`). One per request; the math is `WritingProgressEstimate`.
@MainActor
@Observable
final class WritingProgressMeter {
    private(set) var estimate: WritingProgressEstimate
    /// The pass a writer that works in several is on (Ultra AI: the draft, its claims checked, the polish), for the star's arcs
    /// (`UltraPassOrbit`); nil for a writer that writes in one go.
    private(set) var pass: WritingPass?
    /// When each pass began, in the meter's seconds, by its index: Ultra AI's chapters round the star (`UltraWaitTimeline`).
    private(set) var passStarts: [TimeInterval] = []
    /// Each step (`arrivalStep` of a pass) its words came, in order: a spark from Ultra AI's star (`UltraWaitScene`).
    private(set) var arrivals: [WritingArrival] = []
    private let clock: () -> TimeInterval

    /// How far a pass's words come between two arrivals: up to about 16 a pass, however finely the model streams (more cluttered the scene).
    static let arrivalStep = 0.06

    /// - Parameter now: the time in seconds; the real one by default, tests move their own.
    init(expectedWords: Int, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        estimate = WritingProgressEstimate(expectedWords: expectedWords)
        clock = now
    }

    /// A meter for `request`, expecting the fewest words the creator asked for (what the model writes, about).
    convenience init(for request: ScriptRequest) {
        self.init(expectedWords: ReadTime.words(for: request.targetRange.lowerBound))
    }

    var isFinished: Bool { estimate.isFinished }

    /// The meter's time now, in seconds: what `passStarts` and `arrivals` are counted in.
    var now: TimeInterval { clock() }

    /// The words the script is expected to have.
    var expectedWords: Int { estimate.expectedWords }

    /// How far the pass on now looks, 0…1 (`WritingPass.shown`); 0 for a writer that writes in one go.
    var passFraction: Double { pass?.shown(at: clock()) ?? 0 }

    /// How much is written now, 0…1. A writer that works in passes is as far as its arcs show (`UltraPassOrbit`): the passes done and the
    /// one on now, each an equal share. Its words alone ran ahead of the arcs (82% under an arc a third of the way round: the owner saw it,
    /// 29/10/2026). Never 100% before the script is there.
    var fraction: Double {
        guard let pass, !isFinished else { return estimate.fraction(at: clock()) }
        return min(0.99, (Double(pass.index) + pass.shown(at: clock())) / Double(max(1, pass.count)))
    }

    func record(_ event: ScriptWritingEvent) {
        estimate.record(event, at: clock())
    }

    /// A writer that works in passes starts pass `index` (from 0) of `count`.
    func begin(pass index: Int, of count: Int) {
        let time = clock()
        pass = WritingPass(index: index, count: count, startedAt: time)
        while passStarts.count <= index { passStarts.append(time) }
    }

    /// The pass on now has come `fraction` of the way, 0…1, from its words; it never goes back. Each `arrivalStep` of it is an arrival.
    func advance(pass fraction: Double) {
        guard let current = pass, fraction > current.fraction else { return }
        let reached = min(1, fraction)
        pass?.fraction = reached
        let last = arrivals.last { $0.pass == current.index }?.fraction ?? 0
        if reached - last >= Self.arrivalStep - 1e-9 {
            arrivals.append(WritingArrival(pass: current.index, fraction: reached, time: clock()))
        }
    }

    /// The script is there: 100%.
    func finish() {
        estimate.finish()
    }
}
