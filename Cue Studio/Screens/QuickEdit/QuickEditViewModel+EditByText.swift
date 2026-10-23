//
//  QuickEditViewModel+EditByText.swift
//  Cue Studio
//

import Foundation

/// Edit by text (`ClipsViewModel+TranscriptEdit`) meeting the captions: "Fix caption text" opens the line with the picked
/// words in Captions, and listening for the words is the captions listening, with lines that stay hidden if they were.
extension QuickEditViewModel {
    /// "Fix caption text": the caption line with the first picked word, open for writing; nothing is cut.
    func fixCaptionOfSelectedWords() {
        guard let word = clips.selectedTranscriptWords.first(where: { !$0.isRemoved }), let start = word.editedStart else { return }
        let line = edit.captions.first { cue in
            cue.sourceID == word.sourceID && cue.start <= word.span.end && word.span.start < cue.end
        }
        sheet = nil
        clips.transcriptSelection = nil
        guard let line else {
            toast.show(String(localized: "No caption line for these words"))
            return
        }
        panel = .captions
        captions.pickCaptionLine(line.id, at: start)
        captions.focusesCaptionField = true
    }

    /// Listens to the video for its words (as captions do), when there is no transcript yet. Captions that weren't showing stay
    /// hidden: listening for Edit by text doesn't turn them on.
    func listenForTranscript() {
        captions.keepsCaptionsHiddenAfterListening = !edit.showsCaptions
        captions.makeCaptions()
    }
}
