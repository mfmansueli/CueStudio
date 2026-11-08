//
//  EditSnapshot+Cuts.swift
//  Cue Studio
//

import Foundation

nonisolated extension EditSnapshot {
    /// This step with its layers placed for its timeline (`CutFollowing`): `origin` is where they were before (the step a gesture
    /// began from, so a handle dragged out and back leaves them as they were), `current` the edit now. A layer this step changed
    /// itself (Reverse and Replace clip place what was on the clip, a copied clip gets copies) is placed from where the step put
    /// it; one it didn't, from where it was in `origin`. Music and sounds a step changed are left as it set them.
    func followingCuts(from origin: EditSnapshot, current: EditSnapshot) -> EditSnapshot {
        var next = self
        let timelines = (origin: origin.timeline, current: current.timeline, next: timeline)
        next.texts = Self.followed(texts, origin: origin.texts, current: current.texts, timelines: timelines, rule: CutFollowing.text) {
            $0.span = $1.span
            $0.clipAnchor = $1.clipAnchor
        }
        next.media = Self.followed(media, origin: origin.media, current: current.media, timelines: timelines, rule: CutFollowing.media) {
            $0.span = $1.span
            $0.clipAnchor = $1.clipAnchor
            $0.tail = $1.tail
            $0.mediaStart = $1.mediaStart
            $0.keyframes = $1.keyframes
        }
        next.voiceOvers = Self.followed(
            voiceOvers, origin: origin.voiceOvers, current: current.voiceOvers, timelines: timelines, rule: CutFollowing.voiceOver
        ) {
            $0.anchor = $1.anchor
            $0.clipAnchor = $1.clipAnchor
        }
        if music == current.music, let before = origin.music, let now = current.music {
            let followed = CutFollowing.music(before, from: origin.timeline, to: timeline)
            next.music = now.map { clip in
                guard let moved = followed.first(where: { $0.id == clip.id }) else { return clip }
                var placed = clip
                placed.start = moved.start
                return placed
            }
        }
        return next
    }

    /// `layers` placed on the step's timeline (`timelines.next`) by `rule`: each one unchanged since `current` from where it
    /// was in `origin` (on `origin`'s timeline: `place` copies only where it goes, so what changed meanwhile stays), each other
    /// one from where it is (on `current`'s).
    private static func followed<Layer: Identifiable & Equatable>(
        _ layers: [Layer], origin: [Layer], current: [Layer],
        timelines: (origin: EditTimeline, current: EditTimeline, next: EditTimeline),
        rule: (Layer, EditTimeline, EditTimeline) -> Layer, place: (inout Layer, Layer) -> Void
    ) -> [Layer] {
        guard timelines.next.isArranged else { return layers }
        let before = Dictionary(origin.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let now = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return layers.map { layer in
            guard let was = before[layer.id], now[layer.id] == layer else { return rule(layer, timelines.current, timelines.next) }
            var placed = layer
            place(&placed, rule(was, timelines.origin, timelines.next))
            return placed
        }
    }
}
