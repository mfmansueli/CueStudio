//
//  QuickEditViewModel+VoiceOver.swift
//  Cue Studio
//

import Foundation

/// Voice-over: Record plays the edit from the playhead (muted, so the take's sound doesn't leak
/// into the mic) while the narration records; Stop adds it where it started and plays it back;
/// then Re-record or Delete. Each narration has its own volume. Recorded on the device.
extension QuickEditViewModel {
    var isRecordingVoiceOver: Bool { recorder.isRecording }

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
            toast.show(
                String(localized: "Mic is off for Cue"),
                action: ToastAction(title: String(localized: "Settings")) { [weak self] in self?.opensSettings() }
            )
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
            noteFailure(error, "voiceOverStart")
            toast.show(EditorErrorMessage.text(for: error, otherwise: String(localized: "Couldn't start recording")))
            return
        }
        recordingStart = start
        // The script on screen starts with the recording (`QuickEditViewModel+NarrationScript`).
        narrationPace.start(at: .now)
        Haptics.record()
        player.isMuted = true
        player.play()
    }

    /// Stops recording, adds the narration where it started and plays it back.
    func stopVoiceOver() {
        let start = recordingStart
        recordingStart = nil
        narrationPace.reset()
        // The microphone stops first: the video stopping under it is then no recording to stop again (`playingStopped`).
        let recorded = recorder.stop()
        player.pause()
        player.isMuted = false
        guard let recorded, let start else { return }
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

    /// The video stopped playing under a narration being recorded (its end, Pause): the narration stops with it and is
    /// added. Recording the screen or mirroring it leaves both going.
    func playingStopped() {
        guard recorder.isRecording, recordingStart != nil else { return }
        stopVoiceOver()
    }

    /// The narration stopped without Stop. A call or another app took the microphone: what was recorded is added, like Stop
    /// would, and the creator is told why it stopped. The file couldn't be written: nothing usable is left, it goes, and the
    /// creator is told to record again.
    func voiceOverStoppedByItself(_ reason: VoiceOverStop) {
        switch reason {
        case .interrupted:
            stopVoiceOver()
            toast.show(String(localized: "Recording stopped · Another app took the microphone"))
        case .failed:
            noteFailure(VoiceOverError.couldNotWrite, "voiceOverRecord")
            cancelVoiceOver()
            toast.show(String(localized: "Couldn't record the voice-over · Try again"))
        }
    }

    /// Stops and drops what was being recorded.
    func cancelVoiceOver() {
        recorder.cancel()
        recordingStart = nil
        narrationPace.reset()
        player.pause()
        player.isMuted = false
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

    /// Moves one end of a narration to `time` (edited seconds). The start takes the recording along: later skips its
    /// beginning, back brings it again, never before the recording's start; the end never goes past the recording's.
    func resizeVoiceOver(_ id: UUID, edge: LayerEdge, to time: TimeInterval) {
        guard let clip = edit.voiceOvers.first(where: { $0.id == id }), let span = clip.editedSpan(in: edit.timeline) else { return }
        let shortest = MediaOverlay.minimumDuration
        let offset = clip.offset ?? 0
        switch edge {
        case .start:
            let earliest = max(0, span.start - offset)
            let start = min(max(time, earliest), span.end - shortest)
            let moved = start - span.start
            let pinned = edit.pin(TimeSpan(start: start, end: span.end))
            change { snapshot in
                guard let index = snapshot.voiceOvers.firstIndex(where: { $0.id == id }) else { return }
                snapshot.voiceOvers[index].offset = offset + moved
                snapshot.voiceOvers[index].length = clip.length.map { $0 - moved }
                snapshot.voiceOvers[index].anchor = pinned.span.start
                snapshot.voiceOvers[index].clipAnchor = pinned.anchor
            }
        case .end:
            let longest = min(clip.duration - offset, edit.editedDuration - span.start)
            let length = min(max(time - span.start, shortest), max(shortest, longest))
            change { snapshot in
                guard let index = snapshot.voiceOvers.firstIndex(where: { $0.id == id }) else { return }
                snapshot.voiceOvers[index].length = length
            }
        }
    }

    func deleteVoiceOver(_ id: UUID) {
        change { $0.voiceOvers.removeAll { $0.id == id } }
        sayUndoable(String(localized: "Voice-over deleted"))
    }
}
