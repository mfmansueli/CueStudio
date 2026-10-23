//
//  QuickEditViewModel+FrameStep.swift
//  Cue Studio
//

import Foundation

/// ‹ › beside Play: the playhead moves one frame of the video as it plays, paused, so Split, a trim to the playhead or a cover
/// frame lands exactly where the creator wants (cutting on a phone by dragging alone is the most repeated complaint about
/// mobile editors).
extension QuickEditViewModel {
    /// One frame back (`-1`) or forward (`1`), from the frame the playhead is on.
    func stepFrame(_ direction: Int) {
        guard isReady, !recorder.isRecording else { return }
        player.pause()
        let frame = 1 / frameRate
        let onFrame = (player.currentTime / frame).rounded() * frame
        let target = min(max(onFrame + Double(direction.signum()) * frame, 0), edit.editedDuration)
        guard abs(target - player.currentTime) > frame / 1000 else { return }
        player.seek(to: target)
        Haptics.selection()
    }
}
