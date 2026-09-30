//
//  OverlayMotion.swift
//  Cue Studio
//

import Foundation

/// An item's keyframes, read at a moment: where it is, how big and how opaque. Before the first
/// keyframe it holds the first; after the last, the last; between two, it moves from one to the
/// next at the pace the next one asks for. Pure, so the preview, the export and the tests read the
/// same motion.
nonisolated struct OverlayMotion: Hashable, Sendable {
    struct State: Equatable {
        var center: OverlayPoint
        var scale: Double
        var opacity: Double
    }

    /// In time order.
    let keyframes: [OverlayKeyframe]

    init(_ keyframes: [OverlayKeyframe]) {
        self.keyframes = keyframes.sorted { $0.time < $1.time }
    }

    /// The state `time` seconds into the item; nil without keyframes (the item stands still).
    func state(at time: TimeInterval) -> State? {
        guard let first = keyframes.first, let last = keyframes.last else { return nil }
        if time <= first.time { return State(first) }
        if time >= last.time { return State(last) }
        guard let next = keyframes.firstIndex(where: { $0.time > time }), next > 0 else { return State(last) }
        let from = keyframes[next - 1]
        let to = keyframes[next]
        let span = to.time - from.time
        let progress = to.easing.apply(span > 0 ? (time - from.time) / span : 1)
        return State(
            center: OverlayPoint(
                x: from.center.x + (to.center.x - from.center.x) * progress,
                y: from.center.y + (to.center.y - from.center.y) * progress
            ),
            scale: from.scale + (to.scale - from.scale) * progress,
            opacity: from.opacity + (to.opacity - from.opacity) * progress
        )
    }
}

nonisolated extension OverlayMotion.State {
    init(_ keyframe: OverlayKeyframe) {
        self.init(center: keyframe.center, scale: keyframe.scale, opacity: keyframe.opacity)
    }
}
