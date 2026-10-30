//
//  SpokenSpans.swift
//  Cue Studio
//

import Foundation

/// Where someone speaks in an edit, for music that goes down under the voice (`MusicEnvelope`), on the drawn timeline's
/// seconds (`edit.timeline`; music is placed from `window.start`).
///
/// `spans` is what music with `MusicClip.duck` goes down under: the recordings' speech in the clips whose sound is heard (a
/// muted clip, one at 0%, or one whose sound went to a track of its own isn't someone speaking), each voice-over's own speech
/// (its pauses are pauses; a recorded or typed narration whose speech wasn't found counts whole), and the speech in a clip's
/// sound taken out to the music track, where it now plays. `legacySpans` is how music saved before heard it, so it sounds as it
/// did: every clip's speech, and every voice-over from its first moment to its last.
nonisolated struct SpokenSpans: Hashable, Sendable {
    var spans: [TimeSpan]
    var legacySpans: [TimeSpan]

    init(edit: TakeEdit, speech: VoiceActivity, window: TimeSpan) {
        let narrations = edit.voiceOvers.compactMap { clip in clip.editedSpan(in: edit.timeline).map { (clip, $0) } }
        legacySpans = speech.editedSpans(in: edit.timeline) + narrations.map(\.1)
        var heard = speech.editedSpans(in: edit.timeline, heardOnly: true)
        for (clip, span) in narrations where clip.volume > 0.001 {
            heard += Self.placed(speech.files[clip.fileName], playing: span, from: clip.offset ?? 0) ?? [span]
        }
        for music in edit.music where music.extractedFrom != nil && !music.isMuted && music.volume > 0.001 {
            let start = window.start + music.start
            let span = TimeSpan(start: start, end: min(window.end, start + music.length))
            guard span.duration > 0.05 else { continue }
            heard += Self.placed(speech.files[music.fileName], playing: span, from: music.offset) ?? []
        }
        spans = TimeSpan.merged(heard)
    }

    /// The speech of a file (its own seconds) where it plays: from `offset` into the file at `span.start`, cut to `span`; nil
    /// when the file's speech isn't known.
    static func placed(_ fileSpeech: [TimeSpan]?, playing span: TimeSpan, from offset: TimeInterval) -> [TimeSpan]? {
        guard let fileSpeech else { return nil }
        let shift = span.start - offset
        return fileSpeech.compactMap { spoken in
            let start = max(span.start, spoken.start + shift), end = min(span.end, spoken.end + shift)
            return end - start > 0.01 ? TimeSpan(start: start, end: end) : nil
        }
    }
}
