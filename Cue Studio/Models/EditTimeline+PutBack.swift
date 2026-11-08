//
//  EditTimeline+PutBack.swift
//  Cue Studio
//

import Foundation

/// Put back (D7): a stretch of a recording that was taken out (a pause, a filler, words cut by text) comes back where it was,
/// and only it: what the edit gained or lost since stays as it is. A stretch comes back next to what played right before it in
/// its recording (the clip that ends where it starts), else right before what played after it, so a clip moved or sped up
/// since never stops it. It plays at the speed of the clip it joins. In a montage each clip that played it is a place of its own
/// (a copied clip: two), put back one at a time.
///
/// It never comes back approximately: when no clip of its recording touches it any more (the clips around it were deleted, or
/// trimmed past it), there is no place, and `putBackBlock` says why.
nonisolated extension EditTimeline {
    /// How close two seconds of a recording are to count as the same edge (a cut's rounding).
    static let putBackTolerance: TimeInterval = 0.002

    /// Where a removed stretch can come back: next to the clip `segmentID`, after its end or before its start, at `editedTime`
    /// in the edit.
    struct PutBackPlace: Hashable, Sendable {
        let segmentID: UUID
        let edge: PutBackEdge
        /// Where it comes back in the edit.
        let editedTime: TimeInterval
    }

    /// Which side of its clip a stretch comes back on.
    enum PutBackEdge: Hashable, Sendable {
        /// It continues the clip: the clip's end grows into it.
        case after
        /// It comes before the clip: the clip's start grows back into it.
        case before
    }

    /// Why a removed stretch has no place to come back.
    enum PutBackBlock: Hashable, Sendable {
        /// It plays already (a handle or an Undo brought it back).
        case alreadyPlays
        /// It lies past the start or end the edit was trimmed to.
        case trimmedOff
        /// No clip of its recording touches it any more: the clips around it were deleted.
        case clipsGone
    }

    /// Every place `span` of the recording `source` (nil: the take) can come back, in the order the edit plays them; empty when
    /// none (`putBackBlock`).
    func putBackPlaces(for span: TimeSpan, in source: UUID?) -> [PutBackPlace] {
        let tolerance = Self.putBackTolerance
        guard span.duration > tolerance else { return [] }
        if !isArranged {
            // One recording in its order: one place, if the stretch is between the handles and a clip touches what's missing.
            guard source == nil, let missing = missingSpan(of: span), let place = linearPlace(for: missing) else { return [] }
            return [place]
        }
        var after: [PutBackPlace] = []
        var before: [PutBackPlace] = []
        var playsWhole = false
        for index in segments.indices where segments[index].sourceID == source {
            let piece = segments[index]
            let start = editedStart(ofSegmentAt: index)
            if piece.sourceStart <= span.start + tolerance, piece.sourceEnd >= span.end - tolerance { playsWhole = true }
            // Its end at the stretch, or inside it (part of it plays already, in this clip): each such clip is a place (a copied
            // clip played it twice).
            if piece.sourceEnd >= span.start - tolerance, piece.sourceEnd < span.end - tolerance, piece.sourceStart < span.start + tolerance {
                after.append(PutBackPlace(segmentID: piece.id, edge: .after, editedTime: start + piece.duration))
                continue
            }
            // Its start at the stretch's end (or inside it).
            if piece.sourceStart <= span.end + tolerance, piece.sourceStart > span.start + tolerance, piece.sourceEnd > span.end - tolerance {
                before.append(PutBackPlace(segmentID: piece.id, edge: .before, editedTime: start))
            }
        }
        // The clip after it is a place only when no clip before it is left (deleted, or moved and trimmed) and it doesn't play
        // anywhere yet: the two sides of one removal never count as two places.
        return after.isEmpty && !playsWhole ? Array(before.prefix(1)) : after
    }

    /// Why `span` of `source` can't come back; nil when it can.
    func putBackBlock(for span: TimeSpan, in source: UUID?) -> PutBackBlock? {
        guard putBackPlaces(for: span, in: source).isEmpty else { return nil }
        let tolerance = Self.putBackTolerance
        if !isArranged {
            guard source == nil, min(span.end, trimEnd) - max(span.start, trimStart) > tolerance else { return .trimmedOff }
            return missingSpan(of: span) == nil ? .alreadyPlays : .clipsGone
        }
        let pieces = segments.filter { $0.sourceID == source }
        if span.subtracting(pieces.map(\.span)).allSatisfy({ $0.duration <= tolerance }) { return .alreadyPlays }
        if let first = pieces.map(\.sourceStart).min(), let last = pieces.map(\.sourceEnd).max(),
           span.end <= first + tolerance || span.start >= last - tolerance {
            return .trimmedOff
        }
        return .clipsGone
    }

    /// Puts `span` of `source` back at `place` (one of `putBackPlaces`): what's missing of it there comes back, joined to the
    /// clip, and the seam it closes goes when both sides play the same way. False, and no change, when the place is gone.
    @discardableResult
    mutating func putBack(_ span: TimeSpan, in source: UUID?, at place: PutBackPlace) -> Bool {
        guard putBackPlaces(for: span, in: source).contains(where: { $0.segmentID == place.segmentID && $0.edge == place.edge }) else {
            return false
        }
        guard isArranged else {
            let before = self
            // A stretch removed at the very end (or start) moved that edge: it comes back by moving the edge out again.
            let tolerance = Self.putBackTolerance
            if abs(span.start - trimEnd) <= tolerance, span.end > trimEnd + tolerance {
                trimEnd(to: span.end)
            } else if abs(span.end - trimStart) <= tolerance, span.start < trimStart - tolerance {
                trimStart(to: span.start)
            } else {
                restore([span])
            }
            return self != before
        }
        guard let index = index(ofSegment: place.segmentID) else { return false }
        switch place.edge {
        case .after: return growEnd(ofSegmentAt: index, through: span, in: source)
        case .before: return growStart(ofSegmentAt: index, from: span.start)
        }
    }

    // MARK: - Private

    /// What of `span` doesn't play, between the handles, as one stretch (from the first missing second to the last).
    private func missingSpan(of span: TimeSpan) -> TimeSpan? {
        // Removed right at the edit's end or start (a pause at the end of the take): its removal is what moved that edge, so it
        // isn't trimmed off; past an edge the creator dragged, it is.
        let tolerance = Self.putBackTolerance
        let atEnd = abs(span.start - trimEnd) <= tolerance
        let atStart = abs(span.end - trimStart) <= tolerance
        let clamped = TimeSpan(start: atStart ? span.start : max(span.start, trimStart), end: atEnd ? span.end : min(span.end, trimEnd))
        let missing = clamped.subtracting(keptSpans).filter { $0.duration > Self.putBackTolerance }
        guard let first = missing.first, let last = missing.last else { return nil }
        return TimeSpan(start: first.start, end: last.end)
    }

    /// One recording in its order: the clip ending where `missing` starts, else the one starting where it ends.
    private func linearPlace(for missing: TimeSpan) -> PutBackPlace? {
        let tolerance = Self.putBackTolerance
        if let index = segments.firstIndex(where: { abs($0.sourceEnd - missing.start) <= tolerance }) {
            return PutBackPlace(segmentID: segments[index].id, edge: .after, editedTime: editedStart(ofSegmentAt: index) + segments[index].duration)
        }
        if let index = segments.firstIndex(where: { abs($0.sourceStart - missing.end) <= tolerance }) {
            return PutBackPlace(segmentID: segments[index].id, edge: .before, editedTime: editedStart(ofSegmentAt: index))
        }
        return nil
    }

    /// The clip at `index` plays on into `span` (up to the clip of the same recording right after it in the edit, when that one
    /// starts inside it), and the two become one when they play the same way.
    private mutating func growEnd(ofSegmentAt index: Int, through span: TimeSpan, in source: UUID?) -> Bool {
        let piece = segments[index]
        let next = segments.indices.contains(index + 1) ? segments[index + 1] : nil
        let follows = next.map {
            $0.sourceID == source && $0.sourceStart >= piece.sourceEnd - Self.putBackTolerance && $0.sourceStart <= span.end + Self.putBackTolerance
        } ?? false
        let end = follows ? (next?.sourceStart ?? span.end) : span.end
        guard end - piece.sourceEnd > Self.putBackTolerance else { return false }
        var grown = piece
        if piece.speedCurve == nil {
            grown.sourceEnd = end
            replaceSegment(grown)
        } else {
            // A curved clip keeps its curve: what comes back is a clip of its own after it, at the speed the curve ends on.
            guard let copyID = duplicateSegment(id: piece.id), var copy = segment(id: copyID) else { return false }
            copy.sourceStart = piece.sourceEnd
            copy.sourceEnd = end
            copy.speedCurve = nil
            copy.speed = piece.edgeSpeed(atStart: false)
            copy.animationIn = nil
            copy.animationOut = nil
            copy.soundFadeIn = 0
            copy.soundFadeOut = 0
            replaceSegment(copy)
            grown = copy
        }
        // The seam it closed goes when nothing differs across it.
        if follows, let next, let joined = Self.joined(grown, next) {
            replaceSegment(joined)
            removeSegment(id: next.id)
        }
        return true
    }

    /// The clip at `index` starts earlier, at `start`.
    private mutating func growStart(ofSegmentAt index: Int, from start: TimeInterval) -> Bool {
        let piece = segments[index]
        guard piece.sourceStart - start > Self.putBackTolerance else { return false }
        if piece.speedCurve == nil {
            var grown = piece
            grown.sourceStart = max(0, start)
            return replaceSegment(grown)
        }
        // A curved clip keeps its curve: the clip itself becomes what comes back (it keeps the seam and the way in), and a
        // copy after it plays its curve on.
        guard let copyID = duplicateSegment(id: piece.id), var rest = segment(id: copyID) else { return false }
        rest.animationIn = nil
        rest.soundFadeIn = 0
        replaceSegment(rest)
        var back = piece
        back.sourceEnd = piece.sourceStart
        back.sourceStart = max(0, start)
        back.speedCurve = nil
        back.speed = piece.edgeSpeed(atStart: true)
        back.animationOut = nil
        back.soundFadeOut = 0
        return replaceSegment(back)
    }

    /// `first` and `second` as one clip, when they play the same way and `second` follows straight on (a hard cut, the same
    /// speed, sound, look, frame and effects); nil otherwise.
    private static func joined(_ first: EditSegment, _ second: EditSegment) -> EditSegment? {
        guard first.sourceID == second.sourceID, abs(first.sourceEnd - second.sourceStart) <= putBackTolerance,
              second.transitionIn == .hardCut, first.playsAtSamePace(as: second) else { return nil }
        var alike = second
        alike.id = first.id
        alike.sourceStart = first.sourceStart
        alike.sourceEnd = first.sourceEnd
        alike.transitionIn = first.transitionIn
        alike.transitionDuration = first.transitionDuration
        alike.animationIn = first.animationIn
        alike.animationOut = first.animationOut
        alike.soundFadeIn = first.soundFadeIn
        alike.soundFadeOut = first.soundFadeOut
        guard alike == first else { return nil }
        var joined = first
        joined.sourceEnd = second.sourceEnd
        joined.animationOut = second.animationOut
        joined.soundFadeOut = second.soundFadeOut
        return joined
    }
}
