//
//  AudioViewModel+TextToSpeech.swift
//  Cue Studio
//

import Foundation

/// Text to speech (Audio bar; Edit text on a spoken voice-over): a narration said by a voice on this iPhone, added at the playhead
/// as a voice-over, or replacing the picked spoken one in place (its start, volume and voice effect kept). It then trims, moves
/// and deletes like a recorded one. The sheet works in `TextToSpeechViewModel`; the narration's file is made by `NarrationMaker`.
extension AudioViewModel {
    /// The sheet's model: the picked spoken voice-over's text, voice and speed when it's being changed, else an empty text in
    /// the take's language.
    func makeTextToSpeech() -> TextToSpeechViewModel {
        let replacing = spokenReplacementID.flatMap { id in edit.voiceOvers.first { $0.id == id && $0.spoken != nil } }
        let speech = TextToSpeechViewModel(
            speaker: narrationSpeaker, previews: soundPreviews, replacing: replacing, script: narrationScriptText,
            suggestedLanguage: captionScript?.language?.rawValue ?? Locale.current.identifier(.bcp47)
        )
        // A draft comes back only where it was written: the same voice-over's Edit text, or a new narration.
        if let draft = textToSpeechDraft, draft.replacingID == replacing?.id {
            speech.restore(draft)
            speech.isRestoredDraft = true
        }
        return speech
    }

    /// The sheet closed without Add or Cancel: `draft` is kept when it differs from how the sheet opens fresh.
    func keepTextToSpeechDraft(_ draft: TextToSpeechDraft, opened start: TextToSpeechDraft, wasDraft: Bool) {
        if wasDraft || draft != start {
            textToSpeechDraft = draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft
        }
    }

    /// The made narration: in place of the one being replaced, or a new voice-over at the playhead; picked and played.
    func addSpoken(_ narration: SpokenNarration, fileName: String, duration: TimeInterval) {
        importedFiles.insert(fileName)
        player.pause()
        if let id = spokenReplacementID, edit.voiceOvers.contains(where: { $0.id == id }) {
            change { snapshot in
                guard let index = snapshot.voiceOvers.firstIndex(where: { $0.id == id }) else { return }
                snapshot.voiceOvers[index].fileName = fileName
                snapshot.voiceOvers[index].duration = duration
                snapshot.voiceOvers[index].offset = nil
                snapshot.voiceOvers[index].length = nil
                snapshot.voiceOvers[index].spoken = narration
            }
            spokenReplacementID = nil
            selection = .voiceOver(id)
            playFromStart(of: id)
            sayUndoable(String(localized: "Voice-over replaced"))
            return
        }
        // From the end, it goes at the start.
        let start = player.currentTime >= edit.editedDuration - 0.1 ? 0 : player.currentTime
        var clip = VoiceOverClip(fileName: fileName, duration: duration, anchor: edit.timeline.sourceTime(forEdited: start))
        clip.spoken = narration
        change { $0.voiceOvers.append(clip) }
        selection = .voiceOver(clip.id)
        playFromStart(of: clip.id)
        sayUndoable(String(localized: "Voice-over added"))
    }

    private func playFromStart(of id: UUID) {
        guard let span = edit.voiceOvers.first(where: { $0.id == id })?.editedSpan(in: edit.timeline) else { return }
        player.seek(to: span.start)
        player.play()
    }
}
