//
//  ClipsViewModel+CleanUpStart.swift
//  Cue Studio
//

import Foundation

/// Clean up › Pauses › the row at its top (D9): "Starts at “Today…” · Trim −1.8s" when the take opens on silence, trimmed to a
/// moment before the first sound (`CleanUpStart`), with Undo on the toast and an optional Listen that plays how the video
/// would begin. Nothing plays unless asked. A text, photo or video the creator put on the start keeps it: the row says so.
extension ClipsViewModel {
    /// The trim the edit's start can take; nil when it opens on speech, the silence is short, or it opens on another video.
    var cleanUpStart: CleanUpStart.Proposal? {
        let timeline = edit.timeline
        let visual = edit.editedTexts(in: timeline).map { $0.span.start } + edit.media.compactMap { $0.editedSpan(in: timeline)?.start }
        return CleanUpStart.proposal(
            timeline: timeline, pauses: edit.suggestions.filter { $0.status != .removed },
            words: edit.captionTranscript?.words ?? [], visualStarts: visual
        )
    }

    /// The pause the edit opens on (the start row's), so it isn't a card too.
    var openingPauseID: UUID? {
        let timeline = edit.timeline
        guard let first = timeline.segments.first, first.sourceID == nil else { return nil }
        return edit.suggestions.first { suggestion in
            suggestion.kind == .pause && suggestion.sourceID == nil && suggestion.heardSilence.start <= first.sourceStart + 0.05
                && suggestion.heardSilence.end > first.sourceStart
        }?.id
    }

    /// "Starts at “Today…”", or "Silence at the start" when the words weren't heard.
    func cleanUpStartTitle(_ proposal: CleanUpStart.Proposal) -> String {
        guard let word = proposal.firstWord?.trimmingCharacters(in: .punctuationCharacters), !word.isEmpty else {
            return String(localized: "Silence at the start")
        }
        return String(localized: "Starts at “\(word)…”", comment: "Clean up: the first word said in the take, where the video would start")
    }

    /// "1.8s before the first word", or why it stays.
    func cleanUpStartDetail(_ proposal: CleanUpStart.Proposal) -> String {
        if proposal.keepsIntro { return String(localized: "Kept: your text or video starts there") }
        return String(localized: "\(DurationText.tenths(proposal.saving)) before the first word")
    }

    /// "Trim −1.8s".
    func cleanUpStartAction(_ proposal: CleanUpStart.Proposal) -> String {
        String(localized: "Trim −\(DurationText.tenths(proposal.saving))", comment: "Clean up: the button takes the silence off the start")
    }

    /// Trim: the video starts a moment before the first sound. One undo step, with Undo on the toast.
    func trimToFirstWord() {
        guard isReady, let proposal = cleanUpStart, !proposal.keepsIntro,
              let timeline = CleanUpStart.trimmed(edit.timeline, to: proposal) else { return }
        let saving = DurationText.tenths(edit.editedDuration - timeline.editedDuration)
        player.pause()
        commit(timeline)
        player.seek(to: 0)
        Haptics.delete()
        let title = proposal.firstWord?.trimmingCharacters(in: .punctuationCharacters)
        toast.show(
            title.map { String(localized: "Starts at “\($0)” · −\(saving)", comment: "Toast: the video now starts at this word") }
                ?? String(localized: "Start trimmed · −\(saving)"),
            action: undoAction
        )
    }

    /// Listen: plays the first seconds the video would have after the trim, then the playhead comes back to the start.
    func listenToTrimmedStart() {
        guard isReady, let proposal = cleanUpStart else { return }
        let end = min(edit.editedDuration, proposal.saving + Self.startListenLength)
        guard end > proposal.saving else { return }
        listeningID = Self.startListenID
        play([proposal.saving...end], back: 0)
    }

    /// How much of the new start Listen plays.
    static let startListenLength: TimeInterval = 2.5
    /// Listen's speaker on the start row (it isn't a suggestion's).
    static let startListenID = UUID(uuidString: "00000000-0000-0000-0000-00000000C1EA") ?? UUID()
}
