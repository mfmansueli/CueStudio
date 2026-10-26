//
//  BlurFollowing.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Follows a Blur area's subject through its footage, from where the creator put it, and says where it couldn't. Pure: the
/// faces come from the motion analysis Cue already keeps for each recording (ten times a second, `SubjectSample`), and a drawn
/// area's path from Vision's tracker (`TrackSample`), so it's tested with made-up samples.
///
/// A face is followed face to face, never swapped for whichever is nearest: each next face must be where this one was going
/// and about its size. When two faces could be it (people crossing), it keeps the likelier and marks the moment unchecked;
/// when none can (the face turned away, left the frame, something covered it), the area holds where it was, the stretch is
/// marked, and it picks the face up again when it comes back near where it was lost.
nonisolated enum BlurFollowing {
    /// Where following reached and what it found.
    struct Result: Equatable, Sendable {
        /// The area along the way (seconds of the footage), thinned to the few that keep its path.
        var keyframes: [BlurKeyframe]
        /// Where it may not cover its subject.
        var unchecked: [TimeSpan]
        /// The stretch it looked through.
        var reached: TimeSpan
    }

    /// How far (a share of the frame) the thinned path may stray from the followed one.
    static let tolerance = 0.004
    /// And how far as a share of the area's own size: a small area slips off what it hides long before a large one would.
    static let sizeShare = 0.04
    /// A drawn area moving faster than this share of its box's longer side a frame, for `lasting` frames running (a shake, the
    /// phone picked up), is marked: Vision's box lags there. Measured on the iPhone against a face's landmarks (26/10): it caught
    /// the shake at the end of a take, where an area slipped off a nose, for a few frames marked over a still face; a single fast
    /// frame is the tracker's jitter, and marking those filled a still face with tenth-of-a-second marks.
    static let fastest = 0.1
    static let lasting = 3
    /// Samples further apart than this mean the analysis has nothing in between.
    static let longestStep: TimeInterval = 0.35
    /// A frame, the least a mark lasts.
    static let frame: TimeInterval = 1.0 / 30

    // MARK: - Faces

    /// Follows the face `face` (the one the area was put on at `time`) through `samples`, across `span`, keeping the area as it
    /// sits around the face (`area`: its offset and size in faces).
    static func followFace(_ samples: [SubjectSample], area: NormalizedBox, face: NormalizedBox, at time: TimeInterval, through span: TimeSpan) -> Result {
        let relation = Relation(area: area, around: face)
        let start = min(max(time, span.start), span.end)
        let inside = samples.filter { $0.time >= span.start - frame && $0.time <= span.end + frame }.sorted { $0.time < $1.time }
        var keyframes = [BlurKeyframe(time: start, box: area)]
        var unchecked: [TimeSpan] = []
        for forward in [true, false] {
            let walk: [SubjectSample] = forward
                ? inside.filter { $0.time > start + 0.000_1 }
                : Array(inside.filter { $0.time < start - 0.000_1 }.reversed())
            let end = forward ? span.end : span.start
            var walker = BlurFaceWalker(face: face, time: start, forward: forward)
            for sample in walk {
                if let gap = walker.gap(before: sample.time) { unchecked.append(gap) }
                switch walker.step(to: sample) {
                case .found(let found, let ambiguous, let reacquired):
                    if let reacquired {
                        unchecked.append(reacquired.lost)
                        // Picked up again: the first half second after is checked too (it could be someone else).
                        let after = forward ? TimeSpan(start: sample.time, end: sample.time + 0.5) : TimeSpan(start: sample.time - 0.5, end: sample.time)
                        unchecked.append(after)
                        // Held where it was lost until the face is back.
                        keyframes.append(BlurKeyframe(time: sample.time + (forward ? -frame : frame), box: relation.area(around: reacquired.heldFace)))
                    }
                    if ambiguous { unchecked.append(TimeSpan(start: sample.time - frame * 2, end: sample.time + frame * 2)) }
                    keyframes.append(BlurKeyframe(time: sample.time, box: relation.area(around: found)))
                case .lost:
                    break
                }
            }
            if let lost = walker.lostStretch(to: end) { unchecked.append(lost) }
            // Past the last sample the analysis has, nothing was seen.
            if let last = walk.last?.time, (forward ? end - last : last - end) > longestStep {
                unchecked.append(TimeSpan(start: min(last, end), end: max(last, end)))
            } else if walk.isEmpty, abs(end - start) > longestStep {
                unchecked.append(TimeSpan(start: min(start, end), end: max(start, end)))
            }
        }
        let marked = TimeSpan.merged(unchecked.map { clamp($0, to: span) })
        return Result(keyframes: thinned(steadied(keyframes.sorted { $0.time < $1.time })), unchecked: marked, reached: span)
    }

    /// Vision's face box breathes a little from sample to sample even on a still head: each run of samples (broken where the
    /// face was lost) is smoothed both ways (zero lag, `GaussianSmoothing`), so the area glides with the face instead of
    /// trembling, and fewer keyframes keep its path.
    static func steadied(_ keyframes: [BlurKeyframe]) -> [BlurKeyframe] {
        var runs: [[BlurKeyframe]] = []
        for keyframe in keyframes {
            if let last = runs.last?.last, keyframe.time - last.time <= longestStep, last.box != keyframe.box || keyframe.time - last.time > frame * 1.5 {
                runs[runs.count - 1].append(keyframe)
            } else {
                runs.append([keyframe])
            }
        }
        return runs.flatMap { run -> [BlurKeyframe] in
            guard run.count > 3 else { return run }
            let x = GaussianSmoothing.smoothed(run.map(\.box.midX), sigma: 1)
            let y = GaussianSmoothing.smoothed(run.map(\.box.midY), sigma: 1)
            let width = GaussianSmoothing.smoothed(run.map(\.box.width), sigma: 1.5)
            let height = GaussianSmoothing.smoothed(run.map(\.box.height), sigma: 1.5)
            return run.indices.map { index in
                BlurKeyframe(
                    time: run[index].time,
                    box: NormalizedBox(center: CGPoint(x: x[index], y: y[index]), width: width[index], height: height[index]),
                    isSet: run[index].isSet
                )
            }
        }
    }

    /// The faces of `samples` nearest `time`, for picking one (within a few frames; none when the analysis has nothing there).
    static func faces(in samples: [SubjectSample], at time: TimeInterval) -> [NormalizedBox] {
        guard let nearest = samples.min(by: { abs($0.time - time) < abs($1.time - time) }), abs(nearest.time - time) <= 0.15 else { return [] }
        return nearest.faces
    }

    // MARK: - A drawn area

    /// The area followed by Vision's tracker from `time`: `ahead` and `behind` are the samples it gave each way (the box it
    /// followed was `tracked`; the frame is `frameAspect` wide for 1 tall). Where the tracker stopped short of the area's ends,
    /// wasn't sure, or the area moved too fast for it, is unchecked. The area is never smaller than drawn (`smallest`, a share of
    /// the drawn size): Vision's box around something narrow shrinks as it goes (an eye's, to 70% on the iPhone), and an area
    /// shrinking with it uncovered what it hid while saying it was covered; it still grows with what it follows.
    static func followObject(
        ahead: [TrackSample], behind: [TrackSample], area: NormalizedBox, tracked: NormalizedBox, at time: TimeInterval, through span: TimeSpan,
        frameAspect: Double, unsureBelow: Double = 0.5, share: Double? = sizeShare, smallest: Double = 1, fastest: Double? = fastest,
        lasting: Int = lasting
    ) -> Result {
        let start = min(max(time, span.start), span.end)
        let samples = (behind + ahead).sorted { $0.time < $1.time }
        var keyframes: [BlurKeyframe] = []
        var unchecked: [TimeSpan] = []
        var fastRun: [TimeInterval] = []
        // The tracker's box breathes from frame to frame: its size is smoothed over a few samples, its center isn't.
        let widths = smoothed(samples.map { $0.box.width / max(0.000_1, tracked.width) })
        let heights = smoothed(samples.map { $0.box.height / max(0.000_1, tracked.height) })
        for (index, sample) in samples.enumerated() {
            let scaleX = min(max(widths[index], smallest), 1.8), scaleY = min(max(heights[index], smallest), 1.8)
            let center = CGPoint(
                x: sample.box.midX + (area.midX - tracked.midX) * scaleX, y: sample.box.midY + (area.midY - tracked.midY) * scaleY
            )
            keyframes.append(BlurKeyframe(time: sample.time, box: NormalizedBox(center: center, width: area.width * scaleX, height: area.height * scaleY)))
            if sample.confidence < unsureBelow { unchecked.append(TimeSpan(start: sample.time - frame * 2, end: sample.time + frame * 2)) }
            // Moving faster than the tracker can be trusted (a share of the box's longer side a frame, on the frame as seen): marked.
            if let fastest, index > 0 {
                let before = samples[index - 1]
                let frames = max(1, (sample.time - before.time) / frame)
                let dx = (sample.box.midX - before.box.midX) * frameAspect, dy = sample.box.midY - before.box.midY
                let longer = max(sample.box.width * frameAspect, sample.box.height, 0.000_1)
                let speed = (dx * dx + dy * dy).squareRoot() / longer / frames
                if speed > fastest {
                    fastRun.append(sample.time)
                } else {
                    if fastRun.count >= lasting, let first = fastRun.first, let last = fastRun.last {
                        unchecked.append(TimeSpan(start: first - frame * 3, end: last + frame * 2))
                    }
                    fastRun = []
                }
            }
        }
        if fastRun.count >= lasting, let first = fastRun.first, let last = fastRun.last {
            unchecked.append(TimeSpan(start: first - frame * 3, end: last + frame * 2))
        }
        if keyframes.isEmpty { keyframes = [BlurKeyframe(time: start, box: area)] }
        let first = samples.first?.time ?? start, last = samples.last?.time ?? start
        if last < span.end - frame * 1.5 { unchecked.append(TimeSpan(start: last, end: span.end)) }
        if first > span.start + frame * 1.5 { unchecked.append(TimeSpan(start: span.start, end: first)) }
        return Result(keyframes: thinned(keyframes, share: share), unchecked: TimeSpan.merged(unchecked.map { clamp($0, to: span) }), reached: span)
    }

    // MARK: - Putting it on the area

    /// `region` with `result` laid on: the keyframes following put inside the stretch it reached give way to the new ones (the
    /// creator's own stay), the stretch is checked again, and what it couldn't confirm is marked.
    static func applying(_ result: Result, to region: BlurRegion) -> BlurRegion {
        var next = region
        let reached = result.reached
        let own = region.keyframes.filter { $0.isSet == true }
        next.keyframes.removeAll { $0.isSet != true && $0.time >= reached.start - frame && $0.time <= reached.end + frame }
        let added = result.keyframes.filter { candidate in !own.contains { abs($0.time - candidate.time) < frame } }
        next.keyframes = (next.keyframes + added).sorted { $0.time < $1.time }
        next.markChecked(reached)
        for stretch in result.unchecked { next.markUnchecked(stretch) }
        next.isFollowed = true
        return next
    }

    // MARK: - Thinning

    /// The fewest keyframes that keep the path (center and size) within `tolerance` of the followed one, and within `share`
    /// of the area's size when given, the first and last always (Ramer–Douglas–Peucker over time).
    static func thinned(_ keyframes: [BlurKeyframe], tolerance: Double = tolerance, share: Double? = nil) -> [BlurKeyframe] {
        guard keyframes.count > 2 else { return keyframes }
        var keep = Array(repeating: false, count: keyframes.count)
        keep[0] = true
        keep[keyframes.count - 1] = true
        var stack = [(0, keyframes.count - 1)]
        while let (from, to) = stack.popLast() {
            guard to - from > 1 else { continue }
            let start = keyframes[from], end = keyframes[to]
            var worst = 0.0, worstIndex = from
            for index in (from + 1)..<to {
                let point = keyframes[index]
                let part = (point.time - start.time) / max(0.000_1, end.time - start.time)
                func off(_ value: (BlurKeyframe) -> Double) -> Double {
                    abs(value(point) - (value(start) + (value(end) - value(start)) * part))
                }
                // How far it strays, as a share of how far it may: across in the frame's width, up and down in its height.
                let alongX = share.map { min(tolerance, $0 * point.box.width) } ?? tolerance
                let alongY = share.map { min(tolerance, $0 * point.box.height) } ?? tolerance
                let distance = max(
                    off { $0.box.midX } / max(0.000_001, alongX), off { $0.box.midY } / max(0.000_001, alongY),
                    off { $0.box.width } / 2 / max(0.000_001, alongX), off { $0.box.height } / 2 / max(0.000_001, alongY)
                )
                if distance > worst {
                    worst = distance
                    worstIndex = index
                }
            }
            if worst > 1 {
                keep[worstIndex] = true
                stack.append((from, worstIndex))
                stack.append((worstIndex, to))
            }
        }
        return keyframes.indices.filter { keep[$0] }.map { keyframes[$0] }
    }

    // MARK: - Helpers

    private static func clamp(_ stretch: TimeSpan, to span: TimeSpan) -> TimeSpan {
        TimeSpan(start: max(span.start, stretch.start), end: min(span.end, max(stretch.start, stretch.end)))
    }

    private static func smoothed(_ values: [Double]) -> [Double] {
        values.indices.map { index in
            let window = values[max(0, index - 3)...min(values.count - 1, index + 3)]
            return window.reduce(0, +) / Double(window.count)
        }
    }

    /// How an area sits around a face: its center's offset and its size, in faces.
    private struct Relation {
        let dx: Double, dy: Double, width: Double, height: Double

        init(area: NormalizedBox, around face: NormalizedBox) {
            let faceWidth = max(0.000_1, face.width), faceHeight = max(0.000_1, face.height)
            dx = (area.midX - face.midX) / faceWidth
            dy = (area.midY - face.midY) / faceHeight
            width = area.width / faceWidth
            height = area.height / faceHeight
        }

        func area(around face: NormalizedBox) -> NormalizedBox {
            NormalizedBox(
                center: CGPoint(x: face.midX + dx * face.width, y: face.midY + dy * face.height),
                width: width * face.width, height: height * face.height
            )
        }
    }
}
