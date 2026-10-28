//
//  OverlayMotion.swift
//  Cue Studio
//

import Foundation

/// An item's keyframes, read at a moment: where it is, how big and how opaque, and where a photo's or video's mask is. Before
/// the first keyframe it holds the first; after the last, the last; between two, it moves from one to the next at the pace the
/// next one asks for. The mask goes the same way through the keyframes that have one (`OverlayKeyframe.mask`). Pure, so the
/// preview, the export and the tests read the same motion.
nonisolated struct OverlayMotion: Hashable, Sendable {
    struct State: Hashable {
        var center: OverlayPoint
        var scale: Double
        var opacity: Double
        /// Where the mask is; nil where no keyframe places it (the mask's own placement then).
        var mask: MaskPlacement?
        /// A text's turn, in radians, clockwise on the screen.
        var rotation: Double

        init(center: OverlayPoint, scale: Double, opacity: Double, mask: MaskPlacement? = nil, rotation: Double = 0) {
            self.center = center
            self.scale = scale
            self.opacity = opacity
            self.mask = mask
            self.rotation = rotation
        }
    }

    /// In time order.
    let keyframes: [OverlayKeyframe]
    /// A preset laid over the keyframes (or over `base` without them), on an item that shows for `length` seconds.
    let animation: OverlayAnimation?
    let length: TimeInterval
    /// Where the item is without keyframes.
    let base: State?

    init(_ keyframes: [OverlayKeyframe]) {
        self.keyframes = keyframes.sorted { $0.time < $1.time }
        animation = nil
        length = 0
        base = nil
    }

    /// Keyframes and a preset: the preset moves the item from where its keyframes (or `base`) have it.
    init(_ keyframes: [OverlayKeyframe], animation: OverlayAnimation?, length: TimeInterval, base: State) {
        self.keyframes = keyframes.sorted { $0.time < $1.time }
        self.animation = animation
        self.length = length
        self.base = base
    }

    /// The state `time` seconds into the item; nil when nothing moves it (the item stands still).
    func state(at time: TimeInterval) -> State? {
        guard let animation else { return keyframeState(at: time) }
        guard var state = keyframeState(at: time) ?? base else { return nil }
        let change = animation.modifier(at: time, length: length)
        state.center = OverlayPoint(x: state.center.x + change.dx, y: state.center.y + change.dy)
        state.scale *= change.scale
        state.opacity *= change.opacity
        return state
    }

    private func keyframeState(at time: TimeInterval) -> State? {
        guard var state = placeState(at: time) else { return nil }
        state.mask = maskState(at: time)
        return state
    }

    /// Where the keyframes with a mask have it at `time`; nil when none has one.
    func maskState(at time: TimeInterval) -> MaskPlacement? {
        let masked = keyframes.filter { $0.mask != nil }
        guard let first = masked.first, let last = masked.last, let firstMask = first.mask, let lastMask = last.mask else { return nil }
        if time <= first.time { return firstMask }
        if time >= last.time { return lastMask }
        guard let next = masked.firstIndex(where: { $0.time > time }), next > 0,
              let from = masked[next - 1].mask, let to = masked[next].mask else { return lastMask }
        let span = masked[next].time - masked[next - 1].time
        return from.interpolated(to: to, progress: masked[next].easing.apply(span > 0 ? (time - masked[next - 1].time) / span : 1))
    }

    private func placeState(at time: TimeInterval) -> State? {
        guard let first = keyframes.first, let last = keyframes.last else { return nil }
        // A keyframe without a turn of its own keeps the item's.
        let turn = base?.rotation ?? 0
        if time <= first.time { return State(first, rotation: turn) }
        if time >= last.time { return State(last, rotation: turn) }
        guard let next = keyframes.firstIndex(where: { $0.time > time }), next > 0 else { return State(last, rotation: turn) }
        let from = keyframes[next - 1]
        let to = keyframes[next]
        let span = to.time - from.time
        let progress = to.easing.apply(span > 0 ? (time - from.time) / span : 1)
        let fromTurn = from.rotation ?? turn
        let toTurn = to.rotation ?? turn
        return State(
            center: OverlayPoint(
                x: from.center.x + (to.center.x - from.center.x) * progress,
                y: from.center.y + (to.center.y - from.center.y) * progress
            ),
            scale: from.scale + (to.scale - from.scale) * progress,
            opacity: from.opacity + (to.opacity - from.opacity) * progress,
            rotation: fromTurn + (toTurn - fromTurn) * progress
        )
    }
}

nonisolated extension OverlayMotion.State {
    /// The keyframe's place, size, opacity and turn (`rotation` when it has none of its own); its mask is read apart, through
    /// the keyframes that have one.
    init(_ keyframe: OverlayKeyframe, rotation: Double = 0) {
        self.init(center: keyframe.center, scale: keyframe.scale, opacity: keyframe.opacity, rotation: keyframe.rotation ?? rotation)
    }
}
