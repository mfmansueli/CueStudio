//
//  MediaOverlay+Pieces.swift
//  Cue Studio
//

import Foundation

nonisolated extension MediaOverlay {
    /// Shorter than this, a piece isn't a frame anyone sees.
    static let shortestPiece: TimeInterval = 1.0 / 60

    /// Where it shows in `timeline` (edited seconds) and which second of the file plays where, in the order they play.
    ///
    /// Media that follows the cuts (`followsCuts`) stays with the speech it was laid over: the clips of its recording that
    /// play its stretch show it, and a stretch the edit cut out of that speech is cut out of the media too (removing 5 to
    /// 7 s of the main video under a support removes those 2 s of the support, and what plays after stays in step). A clip of
    /// another recording put in between (Insert in sequence) plays without it, and it picks up after, where the speech does.
    /// Splitting a clip changes nothing. The media keeps its own speed: under a faster clip it shows less of its file, under
    /// a slower one more, never past its end. Past the last clip of its recording (laid across into another recording's
    /// clip) it plays straight on, as long as it was laid.
    ///
    /// Media added before (`followsCuts` nil) plays straight on from its start for as long as it shows, as it always did.
    func pieces(in timeline: EditTimeline) -> [MediaPiece] {
        let pieces: [MediaPiece]
        if followsCuts == true {
            pieces = linkedPieces(in: timeline)
        } else if let span = TakeEdit.editedSpan(span, anchor: clipAnchor, in: timeline) {
            pieces = [MediaPiece(edited: span, fileStart: startInFile)]
        } else {
            pieces = []
        }
        return clippedToFile(pieces)
    }

    /// Where it shows in `timeline`, from where its first piece starts to where its last ends; nil when it doesn't show.
    func editedSpan(in timeline: EditTimeline) -> TimeSpan? {
        let pieces = pieces(in: timeline)
        guard let first = pieces.first, let last = pieces.last else { return nil }
        return TimeSpan(start: first.edited.start, end: last.edited.end)
    }

    /// The second of the file shown at `time` (edited seconds), or nil where it doesn't show.
    func fileTime(at time: TimeInterval, in timeline: EditTimeline) -> TimeInterval? {
        guard let piece = pieces(in: timeline).first(where: { $0.edited.start - 0.000_1 <= time && time <= $0.edited.end + 0.000_1 }) else {
            return nil
        }
        return piece.fileStart + max(0, time - piece.edited.start)
    }

    /// The pieces of media that follows the cuts (see `pieces`).
    private func linkedPieces(in timeline: EditTimeline) -> [MediaPiece] {
        let segments = timeline.segments
        let recording = clipAnchor?.sourceID
        let firstIndex: Int? = if let clipAnchor {
            timeline.segmentIndex(holding: span, anchoredTo: clipAnchor)
        } else {
            segments.firstIndex { $0.sourceID == nil && $0.sourceEnd > span.start + 0.000_1 }
        }
        guard let firstIndex else { return [] }
        var pieces: [MediaPiece] = []
        var editedStart = timeline.editedStart(ofSegmentAt: firstIndex)
        // Seconds of the recording laid out so far, and how many of them the speed saved (or added): the file plays at its own
        // speed, so only what was cut out of the speech is skipped in it.
        var cursor = span.start
        var saved: TimeInterval = 0
        var lastPlayed: Int?
        var index = firstIndex
        while index < segments.count, cursor < span.end - 0.000_1 {
            let segment = segments[index]
            let pieceStart = editedStart
            editedStart += segment.duration
            index += 1
            // Another recording's clip in between: it plays without the media.
            guard segment.sourceID == recording else { continue }
            if segment.sourceEnd <= cursor + 0.000_1 {
                // The recording goes back (a copy, another order): what follows isn't the speech it was laid over.
                if lastPlayed != nil { break }
                continue
            }
            if segment.sourceStart >= span.end - 0.000_1 { break }
            let from = max(segment.sourceStart, cursor)
            let until = min(segment.sourceEnd, span.end)
            let start = pieceStart + segment.editedOffset(forSource: from - segment.sourceStart)
            let end = pieceStart + segment.editedOffset(forSource: until - segment.sourceStart)
            if end - start >= Self.shortestPiece {
                pieces.append(MediaPiece(edited: TimeSpan(start: start, end: end), fileStart: startInFile + (from - span.start) - saved))
            }
            saved += (until - from) - (end - start)
            cursor = until
            lastPlayed = index - 1
        }
        // Laid across into another recording's clip: on past its own recording, straight on, as long as it was laid.
        if cursor < span.end - 0.000_1, let lastPlayed, let last = pieces.last, lastPlayed + 1 < segments.count,
           segments[lastPlayed + 1].sourceID != recording {
            let speed = max(0.000_1, segments[lastPlayed].edgeSpeed(atStart: false))
            let end = min(timeline.editedDuration, last.edited.end + (span.end - cursor) / speed)
            if end - last.edited.end >= Self.shortestPiece {
                pieces[pieces.count - 1].edited.end = end
            }
        }
        return pieces
    }

    /// Never past the end of a video's file: a piece that would be is cut short, and none follows.
    private func clippedToFile(_ pieces: [MediaPiece]) -> [MediaPiece] {
        guard let mediaDuration else { return pieces }
        var result: [MediaPiece] = []
        for var piece in pieces {
            let left = mediaDuration - piece.fileStart
            guard left >= Self.shortestPiece else { break }
            if piece.edited.duration > left {
                piece.edited.end = piece.edited.start + left
                result.append(piece)
                break
            }
            result.append(piece)
        }
        return result
    }
}
