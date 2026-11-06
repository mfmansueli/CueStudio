//
//  CutFollowing.swift
//  Cue Studio
//

import Foundation

/// Where the layers go when the cuts change (`EditDocument.commit`), one rule per kind of layer:
///
/// - **Texts and photos or videos** of a montage (pinned to a clip, `ClipAnchor`) stay on what they were laid over: they show
///   from the first moment of it still in the video to the last. Partly over what was taken out, they keep the rest (their clip
///   deleted, they stay on the part over the next one); a freeze frame or a clip put in their middle, they end with the speech
///   they were laid over, not earlier; a pause taken out under them, they get shorter, as in a video of one take (pinned to its
///   seconds, they always did). A video that plays straight on keeps its frames in step there (its file from the second it
///   had reached). All of it gone, they stay as they are: deleting a clip takes them with it (`TakeEdit.removingClip`).
/// - **Voice-overs** play whole, never cut or squeezed with the speech under them: one whose first moment is gone starts where
///   the edit picks up after it, never in another recording's clip.
/// - **Sound effects and extracted sounds** stay on the moment they were put on (`MusicClip.following`).
/// - **Music** keeps its place in the edit (the creator places it by ear), unless the video got so short that none of it would
///   play: it is kept in view at the end, where it can be dragged back.
///
/// Pure functions of two timelines: undo brings back whatever they moved, with the step.
nonisolated enum CutFollowing {
    /// How close two places are to count as the same (no rewrite for a rounding).
    static let tolerance: TimeInterval = 0.002

    // MARK: - Moments

    /// The part of `span` (edited seconds of `old`) still in `new`: where its first moment still there plays and where its last
    /// does, in both. A moment is still there in the clip that played it, or in a clip the change made out of that clip (a
    /// split's right part, what Clean Up left of it): never in another copy of the same seconds. Nil when none of it plays.
    static func kept(_ span: TimeSpan, from old: EditTimeline, to new: EditTimeline) -> (old: TimeSpan, new: TimeSpan)? {
        let oldIDs = Set(old.segments.map(\.id))
        let newStarts = editedStarts(of: new)
        var first: (old: TimeInterval, new: TimeInterval)?
        var last: (old: TimeInterval, new: TimeInterval)?
        var elapsed: TimeInterval = 0
        for piece in old.segments {
            let pieceStart = elapsed
            elapsed += piece.duration
            let from = max(span.start, pieceStart), until = min(span.end, elapsed)
            guard until - from > 0.000_1 else { continue }
            let sourceFrom = piece.sourceStart + piece.sourceOffset(forEdited: from - pieceStart)
            let sourceUntil = min(piece.sourceEnd, piece.sourceStart + piece.sourceOffset(forEdited: until - pieceStart))
            var earliest: (moment: TimeInterval, new: TimeInterval)?
            var latest: (moment: TimeInterval, new: TimeInterval)?
            for index in new.segments.indices {
                let heir = new.segments[index]
                guard heir.sourceID == piece.sourceID else { continue }
                // The same clip, or one this change made out of it.
                guard heir.id == piece.id || (!oldIDs.contains(heir.id)
                    && heir.sourceStart >= piece.sourceStart - 0.000_1 && heir.sourceEnd <= piece.sourceEnd + 0.000_1) else { continue }
                let start = max(sourceFrom, heir.sourceStart), end = min(sourceUntil, heir.sourceEnd)
                guard end - start > 0.000_1 else { continue }
                if earliest.map({ start < $0.moment }) ?? true {
                    earliest = (start, newStarts[index] + heir.editedOffset(forSource: start - heir.sourceStart))
                }
                if latest.map({ end > $0.moment }) ?? true {
                    latest = (end, newStarts[index] + heir.editedOffset(forSource: end - heir.sourceStart))
                }
            }
            if first == nil, let earliest {
                first = (pieceStart + piece.editedOffset(forSource: earliest.moment - piece.sourceStart), earliest.new)
            }
            if let latest {
                last = (pieceStart + piece.editedOffset(forSource: latest.moment - piece.sourceStart), latest.new)
            }
        }
        guard let first, let last else { return nil }
        return (TimeSpan(start: first.old, end: last.old), TimeSpan(start: first.new, end: last.new))
    }

    /// Whether `anchor` names a clip of `timeline` that plays the recording it says (a clip given another recording by
    /// Reverse or Replace clip in the same step doesn't: what is pinned to it was placed on the new one already).
    static func names(_ anchor: ClipAnchor, in timeline: EditTimeline) -> Bool {
        timeline.segment(id: anchor.segmentID).map { $0.sourceID == anchor.sourceID } ?? false
    }

    // MARK: - Layers

    /// A text after the cuts changed from `old` to `new` (see the type).
    static func text(_ text: TextOverlay, from old: EditTimeline, to new: EditTimeline) -> TextOverlay {
        guard !text.isEmpty, let anchor = text.clipAnchor, new.isArranged, names(anchor, in: old),
              let was = TakeEdit.editedSpan(text.span, anchor: anchor, in: old),
              let place = place(was, now: TakeEdit.editedSpan(text.span, anchor: anchor, in: new), from: old, to: new) else { return text }
        var moved = text
        let pinned = TakeEdit.pin(place.new, in: new)
        moved.clipAnchor = pinned.anchor
        moved.span = pinned.span
        return moved
    }

    /// A photo or video after the cuts changed (see the type). One that follows the cuts already keeps its gaps and its step
    /// (`MediaOverlay.pieces`): it is laid again only when the moment it starts on is gone.
    static func media(_ media: MediaOverlay, from old: EditTimeline, to new: EditTimeline) -> MediaOverlay {
        guard let anchor = media.clipAnchor, new.isArranged, names(anchor, in: old), let was = media.editedSpan(in: old) else { return media }
        var media = media
        if media.followsCuts == true, let keyframes = keyframes(of: media, from: old, to: new) { media.keyframes = keyframes }
        let now = media.editedSpan(in: new)
        guard let place = place(was, now: now, from: old, to: new) else { return media }
        if media.followsCuts == true, let now, abs(now.start - place.new.start) < tolerance { return media }
        var moved = media
        // Its file from the second it had reached where it shows from now.
        if media.mediaDuration != nil, place.old.start > was.start + tolerance, let second = media.fileTime(at: place.old.start, in: old) {
            moved.mediaStart = second
        }
        if media.followsCuts == true {
            let pinned = TakeEdit.pinMedia(place.new, in: new)
            moved.clipAnchor = pinned.anchor
            moved.span = pinned.span
            moved.tail = pinned.tail
        } else {
            let pinned = TakeEdit.pin(place.new, in: new)
            moved.clipAnchor = pinned.anchor
            moved.span = pinned.span
        }
        return moved
    }

    /// A voice-over after the cuts changed (see the type).
    static func voiceOver(_ voice: VoiceOverClip, from old: EditTimeline, to new: EditTimeline) -> VoiceOverClip {
        guard let anchor = voice.clipAnchor, new.isArranged, names(anchor, in: old), let was = voice.editedSpan(in: old),
              // Where the edit picks up: the first moment still there from where it started on.
              let picksUp = kept(TimeSpan(start: was.start, end: old.editedDuration), from: old, to: new)?.new.start else { return voice }
        if let now = voice.editedSpan(in: new), abs(now.start - picksUp) < tolerance { return voice }
        let pinned = TakeEdit.pin(TimeSpan(start: picksUp, end: picksUp + 0.05), in: new)
        var moved = voice
        moved.clipAnchor = pinned.anchor
        moved.anchor = pinned.span.start
        return moved
    }

    /// The music and sounds after the cuts changed (see the type).
    static func music(_ clips: [MusicClip], from old: EditTimeline, to new: EditTimeline) -> [MusicClip] {
        MusicClip.following(clips, from: old, to: new).map { clip in
            guard clip.takesMusicRoom, clip.span(inEditOf: old.editedDuration) != nil, clip.span(inEditOf: new.editedDuration) == nil else {
                return clip
            }
            var kept = clip
            kept.start = max(0, new.editedDuration - min(clip.length, MusicClip.minimumDuration))
            return kept
        }
    }

    // MARK: - Private

    /// The keyframes of media that follows the cuts on the frames they were set on: a clip put in its middle opens a gap in it
    /// (`MediaOverlay.pieces`), and the keyframes after the gap move later by as much, so the motion stays on what it showed (and
    /// back when the gap closes). Nil when none moves.
    private static func keyframes(of media: MediaOverlay, from old: EditTimeline, to new: EditTimeline) -> [OverlayKeyframe]? {
        guard let keyframes = media.keyframes, !keyframes.isEmpty else { return nil }
        let before = media.pieces(in: old), after = media.pieces(in: new)
        guard let start = before.first?.edited.start, let newStart = after.first?.edited.start, before != after else { return nil }
        var changed = false
        let moved = keyframes.map { keyframe -> OverlayKeyframe in
            let time = start + keyframe.time
            // The frame it was set on (in a gap, the last one shown before it, and as far after it).
            guard let piece = before.last(where: { $0.edited.start <= time + 0.000_1 }) else { return keyframe }
            let into = min(time - piece.edited.start, piece.edited.duration)
            let frame = piece.fileStart + into
            guard let shows = after.first(where: { $0.fileStart - 0.000_1 <= frame && frame <= $0.fileStart + $0.edited.duration + 0.000_1 }) else {
                return keyframe
            }
            let edited = shows.edited.start + (frame - shows.fileStart) + (time - piece.edited.start - into)
            var keyframe = keyframe
            if abs(edited - newStart - keyframe.time) > tolerance {
                keyframe.time = max(0, edited - newStart)
                changed = true
            }
            return keyframe
        }
        return changed ? moved.sorted { $0.time < $1.time } : nil
    }

    /// Where something shown over `was` (edited seconds of `old`, `now` in `new` as it is pinned) should show in `new`; nil when
    /// it stays as it is: it shows there already, nothing of it is left, or what is left would reach over a clip it wasn't over
    /// (clips put in another order: it goes with the clip it starts on, as it is pinned). A clip new in this change (a freeze
    /// frame, an insert, a split's right part) can be under it.
    private static func place(
        _ was: TimeSpan, now: TimeSpan?, from old: EditTimeline, to new: EditTimeline
    ) -> (old: TimeSpan, new: TimeSpan)? {
        guard let kept = kept(was, from: old, to: new), kept.new.end - kept.new.start > 0.05 else { return nil }
        if let now, abs(now.start - kept.new.start) < tolerance, abs(now.end - kept.new.end) < tolerance { return nil }
        let oldStarts = editedStarts(of: old)
        let newStarts = editedStarts(of: new)
        for (index, segment) in new.segments.enumerated() {
            let shown = TimeSpan(start: newStarts[index], end: newStarts[index] + segment.duration)
            guard shown.end - kept.new.start > 0.000_1, kept.new.end - shown.start > 0.000_1,
                  let before = old.index(ofSegment: segment.id) else { continue }
            let played = TimeSpan(start: oldStarts[before], end: oldStarts[before] + old.segments[before].duration)
            guard played.end - was.start > 0.000_1, was.end - played.start > 0.000_1 else { return nil }
        }
        return kept
    }

    private static func editedStarts(of timeline: EditTimeline) -> [TimeInterval] {
        var starts: [TimeInterval] = []
        var elapsed: TimeInterval = 0
        for segment in timeline.segments {
            starts.append(elapsed)
            elapsed += segment.duration
        }
        return starts
    }
}
