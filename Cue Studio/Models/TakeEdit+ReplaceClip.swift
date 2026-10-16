//
//  TakeEdit+ReplaceClip.swift
//  Cue Studio
//

import Foundation

extension TakeEdit {
    /// Replace clip: what is pinned to the piece `id` (texts, photos and videos, voice-overs) stays at the same moment of the
    /// piece once it plays another recording, `source`, from its start. `old` is the stretch of the old recording the piece
    /// played. Something that started before the piece's start (its start was trimmed off) starts with the piece.
    mutating func moveOverlays(onSegment id: UUID, from old: TimeSpan, to source: UUID) {
        func moved(_ span: TimeSpan) -> TimeSpan {
            let start = max(0, span.start - old.start)
            return TimeSpan(start: start, end: start + max(0, span.end - max(span.start, old.start)))
        }
        for index in texts.indices where texts[index].clipAnchor?.segmentID == id {
            texts[index].clipAnchor?.sourceID = source
            texts[index].span = moved(texts[index].span)
        }
        for index in media.indices where media[index].clipAnchor?.segmentID == id {
            media[index].clipAnchor?.sourceID = source
            media[index].span = moved(media[index].span)
        }
        for index in voiceOvers.indices where voiceOvers[index].clipAnchor?.segmentID == id {
            voiceOvers[index].clipAnchor?.sourceID = source
            voiceOvers[index].anchor = max(0, voiceOvers[index].anchor - old.start)
        }
    }
}
