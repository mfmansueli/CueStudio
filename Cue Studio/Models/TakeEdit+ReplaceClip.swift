//
//  TakeEdit+ReplaceClip.swift
//  Cue Studio
//

import Foundation

extension TakeEdit {
    /// Replace clip: what plays on the piece `id` in `before` (the timeline as it was: texts, photos and videos, voice-overs)
    /// stays at the same moment of the piece once it plays another recording, `source`, from its start. `old` is the stretch
    /// of the old recording the piece played. Something that started before the piece's start (its start was trimmed off)
    /// starts with the piece. What is pinned to the piece but plays in another one (the right part of a split keeps the
    /// left part's pins) stays where it plays.
    mutating func moveOverlays(onSegment id: UUID, from old: TimeSpan, to source: UUID, in before: EditTimeline) {
        guard let replaced = before.index(ofSegment: id) else { return }
        let anchor = ClipAnchor(segmentID: id, sourceID: source)
        func playsOnPiece(_ span: TimeSpan, _ pin: ClipAnchor?) -> Bool {
            pin.flatMap { before.segmentIndex(holding: span, anchoredTo: $0) } == replaced
        }
        func moved(_ span: TimeSpan) -> TimeSpan {
            let start = max(0, span.start - old.start)
            return TimeSpan(start: start, end: start + max(0, span.end - max(span.start, old.start)))
        }
        for index in texts.indices where playsOnPiece(texts[index].span, texts[index].clipAnchor) {
            texts[index].clipAnchor = anchor
            texts[index].span = moved(texts[index].span)
        }
        for index in media.indices where playsOnPiece(media[index].span, media[index].clipAnchor) {
            media[index].clipAnchor = anchor
            media[index].span = moved(media[index].span)
        }
        for index in voiceOvers.indices {
            let start = voiceOvers[index].anchor
            guard playsOnPiece(TimeSpan(start: start, end: start + 0.05), voiceOvers[index].clipAnchor) else { continue }
            voiceOvers[index].clipAnchor = anchor
            voiceOvers[index].anchor = max(0, start - old.start)
        }
    }
}
