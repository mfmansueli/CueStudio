//
//  FakeEditPlayback.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
@testable import Cue_Studio

/// A player whose clock moves only when told to, mapping the playhead onto new edits the way the
/// real one does.
@MainActor
final class FakeEditPlayback: EditPlayback {
    let avPlayer = AVPlayer()
    var currentTime: TimeInterval = 0
    var isPlaying = false
    var state: EditPlaybackState = .ready
    var isProcessing = false
    var reviewedPart: ClosedRange<TimeInterval>?
    var isMuted = false
    var isPlaybackBlocked = false {
        didSet { if isPlaybackBlocked { isPlaying = false } }
    }
    private(set) var shown: [TakeEdit] = []
    private(set) var isScrubbing = false
    private(set) var isStopped = false

    private var duration: TimeInterval { shown.last?.editedDuration ?? 0 }

    func show(_ edit: TakeEdit) {
        if let previous = shown.last, previous.timeline != edit.timeline {
            currentTime = edit.timeline.editedTime(matching: currentTime, in: previous.timeline)
        }
        shown.append(edit)
        currentTime = min(max(0, currentTime), duration)
    }

    func play() { isPlaying = !isPlaybackBlocked }
    func pause() { isPlaying = false }
    func togglePlayback() { if isPlaying { pause() } else { play() } }

    func seek(to time: TimeInterval) {
        currentTime = min(max(0, time), duration)
    }

    func scrub(to time: TimeInterval) {
        isPlaying = false
        isScrubbing = true
        seek(to: time)
    }

    func endScrub() { isScrubbing = false }

    func stop() {
        isStopped = true
        isPlaying = false
    }

    func addFrameHolder(_ owner: AnyObject, hold: @escaping @MainActor (CGImage) -> Void) {}
}
