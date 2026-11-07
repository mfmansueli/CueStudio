//
//  ClipsViewModel+TranscriptEdit.swift
//  Cue Studio
//

import Foundation

/// Edit by text: what was said, word by word, in the order the edit plays it (`TranscriptEditing`). Tap a word to hear it
/// there, tap another to take every word between; Cut from video takes those words out of the video (picture, sound, captions
/// and what is pinned to them move together, with a natural pause kept), one undo step; Put back brings cut words of the take
/// back. Fix caption text changes the words a caption shows and never cuts anything: they are kept apart on purpose.
extension ClipsViewModel {
    var transcriptWords: [TranscriptWord] {
        TranscriptEditing.words(in: edit)
    }

    var hasTranscript: Bool { TranscriptEditing.hasTranscript(edit) }

    /// The picked words, in order.
    var selectedTranscriptWords: [TranscriptWord] {
        guard let range = transcriptSelection else { return [] }
        let words = transcriptWords
        guard words.indices.contains(range.lowerBound), words.indices.contains(range.upperBound) else { return [] }
        return Array(words[range])
    }

    /// "Pick again": no word picked.
    func clearTranscriptSelection() {
        Haptics.selection()
        transcriptSelection = nil
    }

    /// A word tapped: picked alone (the playhead goes to it), or, with a word already picked, every word between them; the only
    /// picked word tapped again lets go.
    func tapTranscriptWord(at index: Int) {
        let words = transcriptWords
        guard words.indices.contains(index) else { return }
        let isPickingEnd = transcriptSelection.map { $0.lowerBound == $0.upperBound } ?? false
        // A hesitation is a mark: tapped while no pick waits for its end, it switches between Remove and Keep.
        if !isPickingEnd, let filler = transcriptMarks(in: words).fillers[index] {
            toggleMark(filler.id)
            return
        }
        Haptics.selection()
        if let range = transcriptSelection, range.lowerBound == range.upperBound {
            if range.lowerBound == index {
                transcriptSelection = nil
                return
            }
            transcriptSelection = min(range.lowerBound, index)...max(range.lowerBound, index)
        } else {
            transcriptSelection = index...index
        }
        if let start = words[index].editedStart {
            player.pause()
            player.seek(to: start)
        }
    }

    /// "Cut from video": the picked words go from the video, each stretch from its own recording. One undo step, with Undo on
    /// the toast.
    func cutSelectedWords() {
        let picked = selectedTranscriptWords.filter { !$0.isRemoved }
        guard isReady, !picked.isEmpty else { return }
        var timeline = edit.timeline
        var removed: TimeInterval = 0
        for run in Self.runs(of: picked) {
            guard let first = run.first, let last = run.last else { continue }
            let span = TranscriptEditing.cut(
                from: first, to: last, transcript: transcript(ofRecording: first.sourceID),
                recordingLength: edit.timeline.duration(ofSource: first.sourceID)
            )
            // Arranged, only the clip the words were read in: a copy of it keeps them.
            let clips = timeline.isArranged ? Set(run.compactMap(\.segmentID)) : nil
            if timeline.remove([span], in: first.sourceID, only: clips) { removed += span.duration }
        }
        guard timeline != edit.timeline else {
            toast.show(String(localized: "Keep at least one section"), kind: .problem)
            return
        }
        player.pause()
        commit(timeline)
        transcriptSelection = nil
        Haptics.delete()
        toast.show(
            String(localized: "\(picked.count) words cut · \(DurationText.tenths(removed))"),
            action: undoAction
        )
    }

    /// "Put back": cut words come back where they were (in a montage, after the clip they are listed under: `EditTimeline.putBack`),
    /// and only they. One undo step, with Undo on the toast; when they can't come back, the toast says why and nothing changes.
    func restoreSelectedWords() {
        let picked = selectedTranscriptWords.filter(\.isRemoved)
        guard isReady, !picked.isEmpty else { return }
        var timeline = edit.timeline
        var blocked: EditTimeline.PutBackBlock?
        for run in Self.runs(of: picked) {
            guard let first = run.first, let last = run.last else { continue }
            let span = TranscriptEditing.cut(
                from: first, to: last, transcript: transcript(ofRecording: first.sourceID),
                recordingLength: timeline.duration(ofSource: first.sourceID)
            )
            let places = timeline.putBackPlaces(for: span, in: first.sourceID)
            // A montage's cut words come back after the clip they are listed under; the take's own edit has one place.
            let place = first.segmentID == nil ? places.first : places.first { $0.segmentID == first.segmentID }
            guard let place else {
                blocked = blocked ?? timeline.putBackBlock(for: span, in: first.sourceID) ?? .clipsGone
                continue
            }
            timeline.putBack(span, in: first.sourceID, at: place)
        }
        guard timeline != edit.timeline else {
            toast.show(
                blocked == .trimmedOff
                    ? String(localized: "Can't put back · these words are past where the video now starts or ends")
                    : String(localized: "Can't put back · the clips around these words were deleted"),
                kind: .problem
            )
            return
        }
        commit(timeline)
        transcriptSelection = nil
        toast.show(String(localized: "Words put back"), action: undoAction)
    }

    // MARK: - Clean up's marks in the words

    /// The hesitations and pauses Text marks in the words of `list` (`transcriptWords`): a filler by the place of its word,
    /// a pause by the place of the word it follows. Tapping a mark switches it between Remove and Keep.
    func transcriptMarks(in list: [TranscriptWord]) -> (fillers: [Int: CleanUpSuggestion], pauses: [Int: CleanUpSuggestion]) {
        let fillers = wordCandidates.filter { $0.kind == .filler }
        let pauses = pauseCandidates
        var fillerAt: [Int: CleanUpSuggestion] = [:]
        var pauseAfter: [Int: CleanUpSuggestion] = [:]
        for (index, word) in list.enumerated() where !word.isRemoved {
            let middle = (word.span.start + word.span.end) / 2
            if let filler = fillers.first(where: { $0.sourceID == word.sourceID && $0.span.start <= middle && middle <= $0.span.end }) {
                fillerAt[index] = filler
            }
            guard list.indices.contains(index + 1) else { continue }
            let next = list[index + 1]
            guard next.sourceID == word.sourceID, next.segmentID == word.segmentID else { continue }
            if let pause = pauses.first(where: {
                $0.sourceID == word.sourceID && $0.span.start >= word.span.end - 0.05 && $0.span.end <= next.span.start + 0.05
            }) {
                pauseAfter[index] = pause
            }
        }
        return (fillerAt, pauseAfter)
    }

    /// The picked words split where they change recording or skip a word of it: each run is one stretch of one recording.
    static func runs(of words: [TranscriptWord]) -> [[TranscriptWord]] {
        var runs: [[TranscriptWord]] = []
        for word in words {
            if let last = runs.last?.last, last.sourceID == word.sourceID, last.segmentID == word.segmentID, word.index == last.index + 1 {
                runs[runs.count - 1].append(word)
            } else {
                runs.append([word])
            }
        }
        return runs
    }

    private func transcript(ofRecording source: UUID?) -> [CaptionWord] {
        (source == nil ? edit.captionTranscript?.words : edit.sourceTranscripts.first { $0.sourceID == source }?.words) ?? []
    }
}
