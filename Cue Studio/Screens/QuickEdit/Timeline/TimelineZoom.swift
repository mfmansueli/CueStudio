//
//  TimelineZoom.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// How far the Trim timeline zooms in time, decided from what is being edited. Pure, so the rules
/// are tested without a screen.
///
/// Zoom 1 fits what the handles can reach between them; above 1 every second is wider. While the
/// red "Remove part" range shows, the zoom follows its length: a short range gets more points per
/// second, down to frame precision (`pointsPerFrameAtMaximum`). The zoom moves in steps of a fixed
/// ladder and only when the range leaves a comfortable band (`zoomInBelow`…`zoomOutAbove` of the
/// room), so dragging an edge never makes the strip jump at every move.
nonisolated enum TimelineZoom {
    /// The steps the automatic zoom takes (and VoiceOver's Zoom in / Zoom out), about 1.6× apart.
    static let ladder: [CGFloat] = [1, 1.5, 2.5, 4, 6, 10, 16, 25, 40, 64, 100, 160, 250, 400, 640, 1_000, 1_600, 2_500]
    /// How wide a frame is at the deepest zoom.
    static let pointsPerFrameAtMaximum: CGFloat = 12
    /// From this width a frame is worth marking: the strip draws a tick on each one.
    static let framePrecisionPointsPerFrame: CGFloat = 6
    /// The range narrower than this share of the room: zoom in…
    static let zoomInBelow: CGFloat = 0.18
    /// …to the first step where it takes at least this share.
    static let zoomInTo: CGFloat = 0.35
    /// The range wider than this share of the room: zoom out…
    static let zoomOutAbove: CGFloat = 0.8
    /// …to the last step where it takes at most this share.
    static let zoomOutTo: CGFloat = 0.5

    /// The deepest zoom: a frame `pointsPerFrameAtMaximum` wide, never less than the fit.
    static func maximum(fitPointsPerSecond: CGFloat, frameRate: Double) -> CGFloat {
        guard fitPointsPerSecond > 0, frameRate > 0 else { return 1 }
        return max(1, CGFloat(frameRate) * pointsPerFrameAtMaximum / fitPointsPerSecond)
    }

    /// The steps up to `maximum`, which is always the last one.
    static func levels(upTo maximum: CGFloat) -> [CGFloat] {
        guard maximum > 1 else { return [1] }
        let between: [CGFloat] = ladder.dropFirst().filter { $0 < maximum * 0.95 }
        return [1] + between + [maximum]
    }

    /// The zoom for a red range `seconds` long, starting from `current`: a step in when the range is
    /// too narrow to see, a step out when it no longer fits comfortably (unless `zoomsOut` is off,
    /// after a pinch), else `current`.
    static func level(
        forSelection seconds: TimeInterval, current: CGFloat, fitPointsPerSecond fit: CGFloat,
        room: CGFloat, maximum: CGFloat, zoomsOut: Bool = true
    ) -> CGFloat {
        guard seconds > 0, fit > 0, room > 0 else { return current }
        func width(_ zoom: CGFloat) -> CGFloat { CGFloat(seconds) * fit * zoom }
        let steps = Self.levels(upTo: maximum)
        if width(current) < room * zoomInBelow, current < maximum - 0.001 {
            return steps.first(where: { width($0) >= room * zoomInTo }) ?? maximum
        }
        if zoomsOut, current > 1, width(current) > room * zoomOutAbove {
            return steps.last(where: { width($0) <= room * zoomOutTo }) ?? 1
        }
        return current
    }

    /// The next step in (or out) from `current`.
    static func step(from current: CGFloat, zoomingIn: Bool, maximum: CGFloat) -> CGFloat {
        let steps = Self.levels(upTo: maximum)
        if zoomingIn { return steps.first(where: { $0 > current * 1.01 }) ?? maximum }
        return steps.last(where: { $0 < current / 1.01 }) ?? 1
    }

    /// Whether frames are wide enough at `pointsPerSecond` to be marked and edited one by one.
    static func isFramePrecise(pointsPerSecond: CGFloat, frameRate: Double) -> Bool {
        frameRate > 0 && pointsPerSecond / CGFloat(frameRate) >= framePrecisionPointsPerFrame
    }
}
