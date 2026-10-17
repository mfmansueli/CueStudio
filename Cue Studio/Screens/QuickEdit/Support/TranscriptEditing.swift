//
//  TranscriptEditing.swift
//  Cue Studio
//

import Foundation

/// Edit by text: what was said, word by word, in the order the edit plays it, and the stretch of a recording that cutting some
/// of the words takes out. Pure, so the sheet and the tests agree.
///
/// A cut keeps the speech natural: it starts a moment before the first word (never into the word before it) and ends a moment
/// before the word that follows, so the pause before the words stays and the one after them goes, as if they were never said.
enum TranscriptEditing {
    /// How long before a word a cut stops.
    static let lead: TimeInterval = 0.05
    /// What a cut keeps after the last word of a recording.
    static let tail: TimeInterval = 0.15

    /// The words of `edit`'s recordings in the order they play. The take's own edit (one recording, in its order) lists the
    /// words cut between its handles too, crossed out, so they can come back; a montage lists what plays, clip by clip.
    static func words(in edit: TakeEdit) -> [TranscriptWord] {
        let timeline = edit.timeline
        func transcript(_ source: UUID?) -> [CaptionWord] {
            let words = source == nil ? edit.captionTranscript?.words : edit.sourceTranscripts.first { $0.sourceID == source }?.words
            return (words ?? []).sorted { $0.start < $1.start }
        }
        if !timeline.isArranged {
            return transcript(nil).enumerated().compactMap { index, word in
                let middle = (word.start + word.end) / 2
                guard middle >= timeline.trimStart - 0.001, middle <= timeline.trimEnd + 0.001 else { return nil }
                let playing = timeline.segments.firstIndex { $0.sourceStart <= middle && middle < $0.sourceEnd }
                return TranscriptWord(
                    id: "take-\(index)", text: word.text, sourceID: nil, span: TimeSpan(start: word.start, end: word.end), index: index,
                    segmentID: playing.map { timeline.segments[$0].id },
                    editedStart: playing.map { position in
                        let segment = timeline.segments[position]
                        return timeline.editedStart(ofSegmentAt: position) + max(0, word.start - segment.sourceStart) / segment.speed
                    }
                )
            }
        }
        var result: [TranscriptWord] = []
        for (position, segment) in timeline.segments.enumerated() {
            for (index, word) in transcript(segment.sourceID).enumerated() {
                let middle = (word.start + word.end) / 2
                guard segment.sourceStart <= middle, middle < segment.sourceEnd else { continue }
                result.append(TranscriptWord(
                    id: "\(segment.id.uuidString)-\(index)", text: word.text, sourceID: segment.sourceID,
                    span: TimeSpan(start: word.start, end: word.end), index: index, segmentID: segment.id,
                    editedStart: timeline.editedStart(ofSegmentAt: position) + max(0, word.start - segment.sourceStart) / segment.speed
                ))
            }
        }
        return result
    }

    /// Whether the edit has anything to list: a transcript of a recording it plays.
    static func hasTranscript(_ edit: TakeEdit) -> Bool {
        edit.playedRecordingIDs.contains { id in
            id == nil ? !(edit.captionTranscript?.words.isEmpty ?? true) : edit.sourceTranscripts.contains { $0.sourceID == id && !$0.words.isEmpty }
        }
    }

    /// The stretch of `first`'s recording that cutting `first` through `last` (same recording, in order) takes out, with the
    /// recording's transcript `transcript` (for the words around them) and its length.
    static func cut(from first: TranscriptWord, to last: TranscriptWord, transcript: [CaptionWord], recordingLength: TimeInterval) -> TimeSpan {
        let sorted = transcript.sorted { $0.start < $1.start }
        let before = sorted.last { $0.end <= first.span.start + 0.001 }
        let after = sorted.first { $0.start >= last.span.end - 0.001 }
        let start = max(before?.end ?? 0, first.span.start - lead)
        let end = after.map { max(last.span.end, $0.start - lead) } ?? min(recordingLength, last.span.end + tail)
        return TimeSpan(start: max(0, start), end: max(start, end))
    }
}
