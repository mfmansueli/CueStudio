//
//  CleanUpSuggestion+Cut.swift
//  Cue Studio
//

import Foundation

/// What removing a suggestion takes out of its recording: the one rule the list, the timeline's yellow marks, the time saved,
/// Listen and the cut itself all read, so what is shown is what is heard and what is cut.
///
/// A pause is a silence (its `span` widened by `SilenceDetector.padding` on each side, as the detector found it); removing it
/// leaves `PauseGap.seconds` of that silence, half on each side, so the words never lose their first or last sound. A pause
/// shorter than the gap plus `minimumCut` isn't touched: a gap is never made longer than the pause was. A word, a filler or a
/// retake goes as it was heard.
nonisolated extension CleanUpSuggestion {
    /// Less than this would be cut: the pause isn't offered (nothing worth hearing changes).
    static let minimumCut: TimeInterval = 0.1

    /// The silence a pause stands for, in seconds of its recording.
    var silence: TimeSpan {
        TimeSpan(start: max(0, span.start - SilenceDetector.padding), end: span.end + SilenceDetector.padding)
    }

    /// What removing it now, with `gap`, takes out of its recording (at most `recordingLength` long); nil for a pause too short
    /// to leave that gap. A removed one gives what it took out (`removedSpan`).
    func cut(leaving gap: PauseGap, recordingLength: TimeInterval? = nil) -> TimeSpan? {
        if status == .removed, let removedSpan { return removedSpan }
        guard kind == .pause else { return span }
        // The detector's span already leaves the padding on each side (Natural, as every cut did before the choice): another
        // gap moves both ends by the difference.
        let change = SilenceDetector.padding - gap.seconds / 2
        var start = max(0, span.start - change)
        var end = span.end + change
        // A sliver left at either end of the recording would go with the cut anyway (`EditTimeline.minimumDuration`): no word
        // is there to keep a gap for, so the cut says so and what it shows is what goes.
        if start < EditTimeline.minimumDuration { start = 0 }
        if let recordingLength, recordingLength - end < EditTimeline.minimumDuration { end = recordingLength }
        let cut = TimeSpan(start: start, end: end)
        guard cut.duration >= Self.minimumCut else { return nil }
        return cut
    }

    /// The suggestion with its span set to what removing it with `gap` takes out (the timeline cuts suggestions by their span);
    /// nil when there's nothing to take out.
    func removal(leaving gap: PauseGap, recordingLength: TimeInterval? = nil) -> CleanUpSuggestion? {
        guard let cut = cut(leaving: gap, recordingLength: recordingLength) else { return nil }
        var removal = self
        removal.span = cut
        return removal
    }
}
