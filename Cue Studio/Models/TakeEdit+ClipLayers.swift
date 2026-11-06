//
//  TakeEdit+ClipLayers.swift
//  Cue Studio
//

import Foundation

nonisolated extension TakeEdit {
    /// The texts, photos or videos and voice-overs (their indices) that start on the clip `id` as it plays now: what Duplicate
    /// copies with it and Reverse keeps in place. By where they play, not by the clip they name: after a split the right part
    /// is a new clip, and what was on it still names the left one (`EditTimeline.segmentIndex(holding:anchoredTo:)`).
    func layersStarting(onSegment id: UUID) -> (texts: [Int], media: [Int], voiceOvers: [Int]) {
        guard let piece = timeline.index(ofSegment: id) else { return ([], [], []) }
        func startsOnPiece(_ span: TimeSpan, _ anchor: ClipAnchor?) -> Bool {
            anchor.flatMap { timeline.segmentIndex(holding: span, anchoredTo: $0) } == piece
        }
        return (
            texts.indices.filter { startsOnPiece(texts[$0].span, texts[$0].clipAnchor) },
            media.indices.filter { startsOnPiece(media[$0].span, media[$0].clipAnchor) },
            voiceOvers.indices.filter { index in
                let at = voiceOvers[index].anchor
                return startsOnPiece(TimeSpan(start: at, end: at + 0.05), voiceOvers[index].clipAnchor)
            }
        )
    }
}
