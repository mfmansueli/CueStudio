//
//  QuickEditViewModel+TranscriptEdit.swift
//  Cue Studio
//

import Foundation

/// Edit by text: what was said, word by word, in the order the edit plays it (`TranscriptEditing`). Tap a word to hear it
/// there, tap another to take every word between; Cut from video takes those words out of the video (picture, sound, captions
/// and what is pinned to them move together, with a natural pause kept), one undo step; Put back brings cut words of the take
/// back. Fix caption text changes the words a caption shows and never cuts anything: they are kept apart on purpose.
extension QuickEditViewModel {
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
            toast.show(String(localized: "Keep at least one section"))
            return
        }
        player.pause()
        commit(timeline)
        transcriptSelection = nil
        Haptics.delete()
        toast.show(
            String(localized: "\(picked.count) words cut · \(DurationText.tenths(removed))"),
            action: ToastAction(title: String(localized: "Undo")) { [weak self] in self?.undo() }
        )
    }

    /// "Put back": cut words of the take come back where they were. One undo step.
    func restoreSelectedWords() {
        let picked = selectedTranscriptWords.filter(\.isRemoved)
        guard isReady, !picked.isEmpty, !edit.timeline.isArranged else { return }
        var timeline = edit.timeline
        let transcript = transcript(ofRecording: nil)
        let spans = Self.runs(of: picked).compactMap { run -> TimeSpan? in
            guard let first = run.first, let last = run.last else { return nil }
            return TranscriptEditing.cut(from: first, to: last, transcript: transcript, recordingLength: edit.sourceDuration)
        }
        timeline.restore(spans)
        guard timeline != edit.timeline else { return }
        commit(timeline)
        transcriptSelection = nil
        toast.show(String(localized: "Words put back"))
    }

    /// "Fix caption text": the caption line with the first picked word, open for writing; nothing is cut.
    func fixCaptionOfSelectedWords() {
        guard let word = selectedTranscriptWords.first(where: { !$0.isRemoved }), let start = word.editedStart else { return }
        let line = edit.captions.first { cue in
            cue.sourceID == word.sourceID && cue.start <= word.span.end && word.span.start < cue.end
        }
        sheet = nil
        transcriptSelection = nil
        guard let line else {
            toast.show(String(localized: "No caption line for these words"))
            return
        }
        panel = .captions
        pickCaptionLine(line.id, at: start)
        focusesCaptionField = true
    }

    /// Listens to the video for its words (as captions do), when there is no transcript yet. Captions that weren't showing stay
    /// hidden: listening for Edit by text doesn't turn them on.
    func listenForTranscript() {
        keepsCaptionsHiddenAfterListening = !edit.showsCaptions
        makeCaptions()
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
