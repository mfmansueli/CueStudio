//
//  EyeGazePlan.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Eye Contact's decision for every analyzed frame of a recording, worked out once from the whole analysis (`make`), so a frame is
/// corrected the same way in the preview, the export and the cover, whatever order they're drawn in, and the decisions can look
/// both ways in time: the correction leaves before a blink starts and comes back after it ends, at no delay.
///
/// The rules are Maxine's (NVIDIA's eye contact, as its open host Locked Gaze runs it), with what a recording allows that a live
/// call doesn't: the eye points are smoothed both ways in time (`EyeTrackSmoother`), the angle comes from the face's distance and the
/// teleprompter's place, and every fade is eased both ways. A frame is corrected where the person is clearly there and reading: one
/// face, a confident mesh, eyes large enough, open (against that person's usual opening around then) and sharp, head roughly
/// frontal, and eyes near their usual reading place. Anything else keeps the eyes it was filmed with. The creator's strength scales
/// the angle (`frame(at:strength:)`). Pure.
nonisolated struct EyeGazePlan: Sendable {
    /// One per analyzed frame, by time.
    let times: [TimeInterval]
    /// What to draw at each (nil: the frame as filmed).
    let frames: [EyeContactFrame?]
    /// Why each frame is held back or eased off (nil: corrected fully).
    let holds: [EyeContactHold?]
    /// Longest gap between a frame's time and the sample that describes it.
    let frameGap: TimeInterval

    /// What to draw for the frame shown at `time` (seconds of the recording) at `strength` (`EyeContactSettings.strength`): the
    /// last frame analyzed at or before it, when it's that frame; nil keeps the frame as filmed.
    func frame(at time: TimeInterval, strength: Double) -> EyeContactFrame? {
        guard let index = index(at: time), var frame = frames[index] else { return nil }
        frame.degrees *= strength
        return frame.degrees > 0.05 ? frame : nil
    }

    /// The sample of the frame shown at `time`: the last one at or before it (2 ms early still counts, for rounding), when it's
    /// within a frame of it.
    func index(at time: TimeInterval) -> Int? {
        var low = 0, high = times.count
        while low < high {
            let middle = (low + high) / 2
            if times[middle] <= time + 0.002 { low = middle + 1 } else { high = middle }
        }
        let index = low - 1
        guard index >= 0, time - times[index] < frameGap else { return nil }
        return index
    }

    /// Over the stretches of the recording `spans`: the share of analyzed frames corrected (fully or partly), and why most of the
    /// others aren't.
    func summary(in spans: [TimeSpan]) -> (corrected: Double, analyzed: Int, mainHold: EyeContactHold?) {
        var corrected = 0, analyzed = 0
        var reasons: [EyeContactHold: Int] = [:]
        for (index, time) in times.enumerated() where spans.contains(where: { $0.contains(time) }) {
            analyzed += 1
            if frames[index] != nil { corrected += 1 } else if let hold = holds[index] { reasons[hold, default: 0] += 1 }
        }
        let main = reasons.max { $0.value < $1.value }?.key
        return (analyzed > 0 ? Double(corrected) / Double(analyzed) : 0, analyzed, main)
    }

    // MARK: - Making

    static func make(_ analysis: EyeContactAnalysis) -> EyeGazePlan {
        let samples = analysis.samples
        let times = samples.map(\.time)
        let count = samples.count
        let eyes = smoothedEyes(samples, size: analysis.size, frameGap: analysis.frameGap)
        let measures = (0..<count).map { index in eyes[index].flatMap { Measure($0, face: samples[index].face, size: analysis.size) } }
        let baselines = Self.baselines(measures, times: times, duration: analysis.duration)
        let sharpness = median(measures.compactMap { $0?.sharpness }.filter { $0 > 0 })
        var holds = [EyeContactHold?](repeating: nil, count: count)
        var amounts = [Double](repeating: 0, count: count)
        // A frame's usual opening and gaze come from the grid point nearest it, so its whole window must be analyzed.
        let window = EyeContactCalibration.baselineWindow + baselineStep / 2
        for index in 0..<count {
            let time = times[index]
            guard analysis.covers(TimeSpan(start: time - window, end: time + window)) else {
                holds[index] = .notAnalyzed
                continue
            }
            guard let measure = measures[index] else {
                holds[index] = .noFace
                continue
            }
            let usual = baselines[min(baselines.count - 1, max(0, Int((time / baselineStep).rounded())))]
            let previous = index > 0 ? measures[index - 1] : nil
            (amounts[index], holds[index]) = decide(measure, previous: previous, usual: usual, usualSharpness: sharpness)
        }
        // Eased both ways: never more than `mostChangePerFrame` a frame, so a blink is met before it starts and left after it ends.
        let eased = limitChange(amounts, times: times)
        var frames = [EyeContactFrame?](repeating: nil, count: count)
        for index in 0..<count where eased[index] > 0.005 {
            guard let measure = measures[index], let shapes = eyes[index] else { continue }
            if eased[index] < 0.99, holds[index] == nil { holds[index] = nearestHold(index, holds: holds, times: times) }
            let unit = shapes.map { shape in
                EyeShape(
                    contour: shape.contour.map { $0 / analysis.sizeVector }, iris: shape.iris / analysis.sizeVector,
                    irisRadius: shape.irisRadius / analysis.width
                )
            }
            frames[index] = EyeContactFrame(eyes: unit, degrees: eased[index] * measure.degrees)
        }
        return EyeGazePlan(times: times, frames: frames, holds: holds, frameGap: analysis.frameGap)
    }

    /// One frame's measures, in pixels of the upright frame.
    private struct Measure {
        let confidence: Double
        let crowded: Bool
        let box: CGRect
        let sharpness: Double
        /// Each eye's corner distance and opening.
        let widths: [Double]
        let openings: [Double]
        /// Tilt of the line between the eyes, degrees.
        let roll: Double
        /// Where both eyes look in the head, degrees (across, down).
        let gaze: SIMD2<Double>
        /// The angle between the teleprompter's text and the lens from this face's distance, degrees.
        let degrees: Double

        init?(_ eyes: [EyeShape], face: EyeSample.Face?, size: CGSize) {
            guard let face, eyes.count == 2 else { return nil }
            confidence = face.confidence
            crowded = face.crowded
            box = face.box
            sharpness = face.sharpness
            widths = eyes.map(\.frame.width)
            openings = eyes.map(\.openness)
            let line = eyes[1].frame.center - eyes[0].frame.center
            roll = atan2(line.y, line.x) * 180 / .pi
            let offset = (eyes[0].irisOffset + eyes[1].irisOffset) / 2
            func degrees(_ share: Double) -> Double { asin(min(1, max(-1, share / EyeContactCalibration.eyeballRadius))) * 180 / .pi }
            gaze = SIMD2(degrees(offset.x), degrees(offset.y))
            self.degrees = EyeGazePlan.degrees(irisRadius: (eyes[0].irisRadius + eyes[1].irisRadius) / 2, frameWidth: Double(size.width))
        }
    }

    /// The angle between looking at the teleprompter's text and at the lens for a face whose iris is `irisRadius` pixels across
    /// half, in a frame `frameWidth` pixels wide, degrees (at most `mostDegrees`).
    static func degrees(irisRadius: Double, frameWidth: Double) -> Double {
        let calibration = EyeContactCalibration.self
        guard irisRadius > 0, frameWidth > 0 else { return 0 }
        let focal = frameWidth / 2 / tan(calibration.fieldOfView / 2 * .pi / 180)
        let distance = focal * calibration.irisDiameter / (2 * irisRadius)
        return min(calibration.mostDegrees, atan(calibration.textBelowLens / distance) * 180 / .pi)
    }

    /// Both eyes of every frame with a face, in upright pixels, smoothed over each stretch of consecutive frames (`EyeTrackSmoother`);
    /// each eye's iris radius is its median over the recording (an iris doesn't change size; the mesh's radius jitters).
    private static func smoothedEyes(_ samples: [EyeSample], size: CGSize, frameGap: TimeInterval) -> [[EyeShape]?] {
        var eyes: [[EyeShape]?] = samples.map { sample in
            guard let face = sample.face, face.eyes.count == 2, face.eyes.allSatisfy(\.isComplete) else { return nil }
            return face.eyes.map { $0.scaled(to: size) }
        }
        let ratios = (0..<2).map { eye in
            median(eyes.compactMap { $0.map { $0[eye].irisRadius / max(0.000_1, $0[eye].frame.width) } })
        }
        var start = 0
        while start < eyes.count {
            guard eyes[start] != nil else { start += 1; continue }
            var end = start + 1
            // A stretch ends at a gap in time or where the face jumps (a cut, or someone else).
            while end < eyes.count, eyes[end] != nil, samples[end].time - samples[end - 1].time <= frameGap * 1.5,
                  !jumped(samples[end - 1].face?.box, samples[end].face?.box) { end += 1 }
            let run = (start..<end).compactMap { index in eyes[index]?.flatMap { $0.contour.flatMap { [$0.x, $0.y] } + [$0.iris.x, $0.iris.y] } }
            let smoothed = EyeTrackSmoother.smooth(
                run, times: samples[start..<end].map(\.time), cutoff: EyeContactCalibration.smoothingCutoff, speed: EyeContactCalibration.smoothingSpeed
            )
            for (offset, values) in smoothed.enumerated() {
                let perEye = EyeShape.pointCount * 2 + 2
                eyes[start + offset] = (0..<2).map { eye in
                    let part = Array(values[eye * perEye..<(eye + 1) * perEye])
                    let contour = stride(from: 0, to: EyeShape.pointCount * 2, by: 2).map { SIMD2(part[$0], part[$0 + 1]) }
                    var shape = EyeShape(contour: contour, iris: SIMD2(part[perEye - 2], part[perEye - 1]), irisRadius: 0)
                    shape.irisRadius = ratios[eye] * shape.frame.width
                    return shape
                }
            }
            start = end
        }
        return eyes
    }

    /// The person's usual eye opening (each eye) and gaze around a moment: the medians of the frames with a face within
    /// `baselineWindow` of it.
    private struct Baseline {
        var openings: [Double]
        var gaze: SIMD2<Double>
    }

    /// Seconds between two baselines: each frame uses the nearest (a median per frame cost 0.4 s for a 34-second take in a Debug
    /// build on an iPhone 15 Pro).
    static let baselineStep: TimeInterval = 0.25

    /// A baseline every `baselineStep` seconds from the recording's start to its end.
    private static func baselines(_ measures: [Measure?], times: [TimeInterval], duration: TimeInterval) -> [Baseline] {
        let window = EyeContactCalibration.baselineWindow
        let points = max(1, Int((duration / baselineStep).rounded(.up)) + 1)
        var result: [Baseline] = []
        result.reserveCapacity(points)
        var first = 0, end = 0
        for point in 0..<points {
            let time = Double(point) * baselineStep
            while first < times.count, times[first] < time - window { first += 1 }
            end = max(end, first)
            while end < times.count, times[end] <= time + window { end += 1 }
            let around = measures[first..<end].compactMap { $0 }
            result.append(Baseline(
                openings: (0..<2).map { eye in median(around.map { $0.openings[eye] }) },
                gaze: SIMD2(median(around.map(\.gaze.x)), median(around.map(\.gaze.y)))
            ))
        }
        return result
    }

    /// How much of the correction a frame gets (0 to 1) and, when not all of it, why (the factor that takes most).
    private static func decide(_ measure: Measure, previous: Measure?, usual: Baseline, usualSharpness: Double) -> (Double, EyeContactHold?) {
        let calibration = EyeContactCalibration.self
        if measure.confidence < calibration.minimumConfidence { return (0, .noFace) }
        if measure.crowded { return (0, .otherPeople) }
        // The face jumped (a cut inside the recording, or someone else): treated as lost for a moment.
        if jumped(previous?.box, measure.box) { return (0, .noFace) }
        var amount = 1.0
        var hold: EyeContactHold?
        func take(_ factor: Double, _ reason: EyeContactHold) {
            if factor < amount { (amount, hold) = (factor, reason) }
        }
        let smallest = measure.widths.min() ?? 0
        take(ramp(smallest, calibration.smallEye), .smallEyes)
        for eye in 0..<2 where usual.openings[eye] > 0 {
            let share = measure.openings[eye] / usual.openings[eye]
            take(share < calibration.closing ? 0 : smootherstep(share, calibration.closing...(calibration.closing + calibration.opening)), .blink)
        }
        take(1 - smootherstep(abs(measure.roll), calibration.roll), .headTurned)
        take(1 - smootherstep(abs(log(max(measure.widths[0], 0.000_1) / max(measure.widths[1], 0.000_1))), calibration.turn), .headTurned)
        let away = measure.gaze - usual.gaze
        take(1 - smootherstep((away * away).sum().squareRoot(), calibration.lookingAway), .lookingAway)
        if usualSharpness > 0, measure.sharpness > 0 {
            take(ramp(measure.sharpness / usualSharpness, calibration.sharpness), .blurred)
        }
        return (amount, amount < 1 ? hold : nil)
    }

    /// `amounts` changed by at most `mostChangePerFrame` (per 1/30 s) from one frame to the next, run forward and backward, the lower
    /// kept: every fade starts early enough to be done when it's needed.
    private static func limitChange(_ amounts: [Double], times: [TimeInterval]) -> [Double] {
        guard amounts.count > 1 else { return amounts }
        let perSecond = EyeContactCalibration.mostChangePerFrame * 30
        var forward = amounts, backward = amounts
        for index in 1..<amounts.count {
            let step = perSecond * max(1.0 / 240, times[index] - times[index - 1])
            forward[index] = min(amounts[index], forward[index - 1] + step)
        }
        for index in stride(from: amounts.count - 2, through: 0, by: -1) {
            let step = perSecond * max(1.0 / 240, times[index + 1] - times[index])
            backward[index] = min(amounts[index], backward[index + 1] + step)
        }
        return zip(forward, backward).map { min($0, $1) }
    }

    /// The reason of the closest frame held back, within a third of a second.
    private static func nearestHold(_ index: Int, holds: [EyeContactHold?], times: [TimeInterval]) -> EyeContactHold? {
        var lower = index, upper = index
        while lower > 0, times[index] - times[lower - 1] <= 0.34 { lower -= 1 }
        while upper < times.count - 1, times[upper + 1] - times[index] <= 0.34 { upper += 1 }
        return (lower...upper)
            .filter { $0 != index && holds[$0] != nil }
            .min { abs(times[$0] - times[index]) < abs(times[$1] - times[index]) }
            .flatMap { holds[$0] }
    }

    /// 0 below the range, 1 above it, a straight line between.
    static func ramp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        guard range.upperBound > range.lowerBound else { return value >= range.upperBound ? 1 : 0 }
        return min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
    }

    /// 0 below the range, 1 above it, eased in and out between (Maxine's quintic).
    static func smootherstep(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        let t = ramp(value, range)
        return t * t * t * (10 + t * (-15 + 6 * t))
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// Whether a face's box moved by more than half its width from one frame to the next.
    private static func jumped(_ before: CGRect?, _ after: CGRect?) -> Bool {
        guard let before, let after else { return false }
        let dx = before.midX - after.midX, dy = before.midY - after.midY
        return Double((dx * dx + dy * dy).squareRoot()) > 0.5 * max(Double(before.width), 0.000_1)
    }
}
