//
//  CaptionJoin.swift
//  Cue Studio
//

import Foundation

/// "Join next" on a caption line, in the order the edit plays: the line that shows after it joins it only when it's the next
/// thing said in the same recording. A line of another recording (another take of a montage) or of an earlier moment (clips
/// put in another order) would mix two recordings' times and words, so it isn't joined, and the creator is told why.
nonisolated enum CaptionJoin: Equatable {
    /// The line (`CaptionCue.id`) that joins it.
    case next(UUID)
    /// Nothing shows after it.
    case lastLine
    /// What shows next is from another recording.
    case otherRecording
    /// What shows next was said before it (the clips were put in another order).
    case earlierInTheRecording

    /// What "Join next" does for the line `cueID` of `edit`.
    static func next(after cueID: UUID, in edit: TakeEdit) -> CaptionJoin {
        guard let first = edit.captions.first(where: { $0.id == cueID }) else { return .lastLine }
        let shown = edit.editedCaptionInstances.sorted { $0.line.start < $1.line.start }
        guard let index = shown.firstIndex(where: { $0.cueID == cueID }) else { return .lastLine }
        // The next line that isn't more of this one (a line across a cut shows in two parts).
        guard let following = shown[(index + 1)...].first(where: { $0.cueID != cueID }),
              let second = edit.captions.first(where: { $0.id == following.cueID }) else { return .lastLine }
        guard second.sourceID == first.sourceID else { return .otherRecording }
        guard second.start >= first.start, second.end > first.end - 0.001 else { return .earlierInTheRecording }
        return .next(second.id)
    }

    /// Why a line can't be joined, for the toast; nil when it can.
    var refusal: String? {
        switch self {
        case .next: nil
        case .lastLine: String(localized: "This is the last line")
        case .otherRecording: String(localized: "The next line is from another clip")
        case .earlierInTheRecording: String(localized: "The next line was said earlier in this clip")
        }
    }
}
