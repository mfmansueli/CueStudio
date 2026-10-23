//
//  ClipsViewModel+SpeedCurve.swift
//  Cue Studio
//

import Foundation

/// Speed › Curve: the picked clip speeds up and slows down as it plays (Hero, Bullet, Ramp up, Ramp down, Montage, Flash in,
/// Flash out, or a curve of the creator's own, shaped by dragging its points). Picking a curve plays the clip to show it; a
/// drag of a point is one undo step. Picking a speed in Normal takes the curve away. While a point or a handle is dragged, the
/// preview stretches curved clips' sound in steps (instant) and renders it along the curve when the finger lifts.
extension ClipsViewModel {
    /// Slowest and fastest a point can be dragged to.
    static let curveSpeedRange = SpeedCurve.speedRange

    /// The picked clip's curve, if it has one.
    var targetCurve: SpeedCurve? { targetClip?.speedCurve }

    /// Speed shows the curves (its Curve tab), or the speeds all along (Normal).
    var showsCurveTab: Bool { showsSpeedCurves || targetCurve != nil }

    func showSpeedCurves(_ shows: Bool) {
        showsSpeedCurves = shows
        // Back to Normal: the clip plays at one speed again.
        if !shows, targetCurve != nil { updateClip { $0.speedCurve = nil } }
    }

    /// A ready-made curve (nil: none, the clip at its speed); the clip plays to show it.
    func setSpeedCurve(_ preset: SpeedCurvePreset?) {
        guard targetCurve?.preset != preset || (preset == nil && targetCurve != nil) else { return }
        updateClip { $0.speedCurve = preset?.curve }
        if preset != nil { previewTargetClip() }
    }

    /// "Custom": five points at the clip's speed, to shape.
    func shapeOwnCurve() {
        let speed = min(max(targetClip?.speed ?? 1, Self.curveSpeedRange.lowerBound), Self.curveSpeedRange.upperBound)
        let points = (0...4).map { SpeedCurve.Point(position: Double($0) / 4, speed: speed) }
        updateClip { $0.speedCurve = SpeedCurve(points: points) }
    }

    /// A point of the curve dragged to `speed` (and, inside the curve, to `position`); the drag is one undo step.
    func moveCurvePoint(_ index: Int, to speed: Double, position: Double? = nil) {
        guard let curve = targetCurve, curve.points.indices.contains(index) else { return }
        var points = curve.points
        points[index].speed = min(max(speed, Self.curveSpeedRange.lowerBound), Self.curveSpeedRange.upperBound)
        if let position, index > 0, index < points.count - 1 {
            let low = points[index - 1].position + 0.05, high = points[index + 1].position - 0.05
            if high > low { points[index].position = min(max(position, low), high) }
        }
        updateClip(key: "clip.curve") { $0.speedCurve = SpeedCurve(points: points) }
    }

    /// A point of the curve is picked to be dragged: the drag is one undo step.
    func beginCurveDrag() {
        shapesCurve = true
        beginChange()
    }

    /// The point picked to be dragged ends its drag: the clip plays to show the new curve.
    func endCurveDrag() {
        shapesCurve = false
        updateCurveSoundStepping()
        endChange()
        previewTargetClip()
    }

    /// Curved clips' sound in steps while a finger shapes the timing (a curve's point, a clip's handle), rendered once it lifts.
    func updateCurveSoundStepping() {
        let steps = shapesCurve || holdsClipHandle
        if player.stepsCurveSound != steps { player.stepsCurveSound = steps }
    }

    /// Where the playhead is along the picked clip's recording (0 to 1); nil when it's elsewhere.
    var curvePlayheadPosition: Double? {
        guard let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return nil }
        let start = edit.timeline.editedStart(ofSegmentAt: index)
        let local = player.currentTime - start
        guard local >= 0, local <= clip.duration, clip.sourceLength > 0 else { return nil }
        return clip.sourceOffset(forEdited: local) / clip.sourceLength
    }

    private func previewTargetClip() {
        guard let clip = targetClip, let index = edit.timeline.index(ofSegment: clip.id) else { return }
        let start = edit.timeline.editedStart(ofSegmentAt: index)
        previewPart(start...(start + min(clip.duration, 6)))
    }
}
