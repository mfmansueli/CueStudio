//
//  CleanUpStart.swift
//  Cue Studio
//

import Foundation

/// Clean up › Pauses › "Starts at “…” · Trim" (D9): the silence before the first word of the take, trimmed from the edit's
/// start, never into the voice. Pure, so the row and the tests agree.
///
/// The silence must be heard, not only read: it comes from the take's loudness (a pause Clean up found running from the edit's
/// start), and the first word's time from the transcript only moves the new start earlier, never later, since word times are
/// approximate. The new start stays `margin` before the first sound, so a soft first consonant or breath is kept. Only the take
/// itself is trimmed (a montage that opens on another video is the creator's intro), only from where the edit starts now, and
/// never under a text, photo or video that starts in what would go (the creator's visual intro): there the row says so instead.
/// Nothing for the end of the take (D9: not now).
nonisolated enum CleanUpStart {
    /// Less silence than this before the first word: no row.
    static let minimumSilence: TimeInterval = 0.3
    /// Kept before the first sound.
    static let margin: TimeInterval = 0.2
    /// Less than this to trim isn't offered.
    static let minimumTrim: TimeInterval = 0.1

    struct Proposal: Equatable {
        /// Where the take's first clip starts now and would start, in seconds of the take.
        let from: TimeInterval
        let to: TimeInterval
        /// What the edit loses at its start, in edited seconds.
        let saving: TimeInterval
        /// The first word said, when the words were heard.
        let firstWord: String?
        /// Something the creator put on the start (a text, a photo or a video) begins in what would go: not trimmed.
        let keepsIntro: Bool
    }

    /// The trim the edit's start can take: `pauses` are Clean up's pause suggestions of the take, `words` its heard words (any
    /// order; none when not heard), `visualStarts` where each text, photo and video on the edit begins (edited seconds).
    static func proposal(
        timeline: EditTimeline, pauses: [CleanUpSuggestion], words: [CaptionWord], visualStarts: [TimeInterval]
    ) -> Proposal? {
        guard let first = timeline.segments.first, first.sourceID == nil else { return nil }
        let start = first.sourceStart
        // The quiet the edit opens on: a pause of the take running across its start.
        let tolerance = 0.05
        guard let quiet = pauses
            .filter({ $0.kind == .pause && $0.sourceID == nil })
            .map(\.heardSilence)
            .first(where: { $0.start <= start + tolerance && $0.end > start }) else { return nil }
        let heard = words.sorted { $0.start < $1.start }.first { $0.end > start + tolerance }
        // Speech already under way where the edit starts: nothing to trim.
        if let heard, heard.start < start - tolerance { return nil }
        let onset = min(quiet.end, heard?.start ?? quiet.end)
        guard onset - start >= minimumSilence else { return nil }
        let to = onset - margin
        guard to - start >= minimumTrim, to < first.sourceEnd - EditTimeline.minimumClipDuration else { return nil }
        let saving = first.editedOffset(forSource: to - start)
        let keepsIntro = visualStarts.contains { $0 < saving - 0.01 }
        return Proposal(from: start, to: to, saving: saving, firstWord: heard?.text, keepsIntro: keepsIntro)
    }

    /// `timeline` starting at the proposal's `to`.
    static func trimmed(_ timeline: EditTimeline, to proposal: Proposal) -> EditTimeline? {
        var trimmed = timeline
        trimmed.trimStart(to: proposal.to)
        return trimmed == timeline ? nil : trimmed
    }
}
