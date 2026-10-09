//
//  QuickEditViewModel+VoiceOver.swift
//  Cue Studio
//

import Foundation

/// Voice-over: Record plays the edit from the playhead (muted, so the take's sound doesn't leak
/// into the mic) while the narration records; Stop adds it where it started and plays it back;
/// then Keep, Redo or Delete. Each narration has its own volume. Recorded on the device.
extension QuickEditViewModel {
    var isRecordingVoiceOver: Bool { recorder.isRecording }

    var reviewedVoiceOver: VoiceOverClip? {
        reviewedVoiceOverID.flatMap { id in edit.voiceOvers.first { $0.id == id } }
    }

    /// "● 00:04.2"
    var recordingElapsedLabel: String {
        DurationText.timecode(recorder.elapsed, total: edit.editedDuration)
    }

    /// Under the record button: where it will start, or how long it has been recording (the microphone's clock: the video
    /// under it may be held while the screen is recorded).
    var voiceOverTimeLabel: String {
        if recordingStart != nil { return DurationText.editor(recorder.elapsed) }
        return String(localized: "Starts at \(DurationText.editor(player.currentTime))")
    }

    func startVoiceOver() async {
        guard isReady, !recorder.isRecording else { return }
        guard await recorder.requestPermission() else {
            toast.show(String(localized: "Mic is off · See Settings"))
            return
        }
        guard !isClosed else { return }
        endChange()
        reviewedVoiceOverID = nil
        // From the end, it starts over from the beginning.
        if player.currentTime >= edit.editedDuration - 0.1 { player.seek(to: 0) }
        let start = player.currentTime
        do {
            try await recorder.start()
        } catch {
            toast.show(error.localizedDescription)
            return
        }
        recordingStart = start
        Haptics.record()
        player.isMuted = true
        player.play()
    }

    /// Stops recording, adds the narration where it started and plays it back.
    func stopVoiceOver() {
        let start = recordingStart
        recordingStart = nil
        player.pause()
        player.isMuted = false
        guard let recorded = recorder.stop(), let start else { return }
        Haptics.record()
        importedFiles.insert(recorded.fileName)
        guard recorded.duration >= 0.3 else {
            EditMediaFiles.remove([recorded.fileName])
            toast.show(String(localized: "Too short to keep"))
            return
        }
        let clip = VoiceOverClip(
            fileName: recorded.fileName, duration: recorded.duration,
            anchor: edit.timeline.sourceTime(forEdited: start)
        )
        change { $0.voiceOvers.append(clip) }
        reviewedVoiceOverID = clip.id
        player.seek(to: start)
        player.play()
    }

    /// Stops and drops what was being recorded.
    func cancelVoiceOver() {
        recorder.cancel()
        recordingStart = nil
        player.pause()
        player.isMuted = false
    }

    func keepVoiceOver() {
        reviewedVoiceOverID = nil
        toast.show(String(localized: "Voice-over kept"))
    }

    /// Takes the narration just recorded away and records again from where it started.
    func redoVoiceOver() async {
        if let clip = reviewedVoiceOver, let span = clip.editedSpan(in: edit.timeline) {
            change { $0.voiceOvers.removeAll { $0.id == clip.id } }
            player.pause()
            player.seek(to: span.start)
        }
        await startVoiceOver()
    }

    /// "Re-record": the narration goes, the playhead goes back to where it started and the
    /// Voice-over panel opens to record again.
    func reRecordVoiceOver(_ id: UUID) {
        guard let clip = edit.voiceOvers.first(where: { $0.id == id }) else { return }
        let start = clip.editedSpan(in: edit.timeline)?.start
        selection = nil
        change { $0.voiceOvers.removeAll { $0.id == id } }
        player.pause()
        if let start { player.seek(to: start) }
        panel = .voiceOver
    }

    func deleteVoiceOver(_ id: UUID) {
        change { $0.voiceOvers.removeAll { $0.id == id } }
        toast.show(String(localized: "Voice-over deleted"))
    }

    func setVoiceOverVolume(_ id: UUID, volume: Double) {
        change { snapshot in
            guard let index = snapshot.voiceOvers.firstIndex(where: { $0.id == id }) else { return }
            snapshot.voiceOvers[index].volume = min(max(volume, VoiceOverClip.volumeRange.lowerBound), VoiceOverClip.volumeRange.upperBound)
        }
    }
}
