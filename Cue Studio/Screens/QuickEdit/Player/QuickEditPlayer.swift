//
//  QuickEditPlayer.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// Plays the edit and is the one clock of Quick edit: the playhead, the time and the timeline all
/// read `currentTime`, which follows the real AVPlayer (never an animation of its own).
///
/// The player item is the edit with its outer ends grown to the whole recording
/// (`EditTimeline.reachable`), and playback is held between the handles. A trim only moves that
/// window, so dragging a handle scrubs real frames and nothing is rebuilt. Removing something,
/// the look and the sound rebuild the item, and the playhead stays on the same moment of the
/// recording.
@MainActor
@Observable
final class QuickEditPlayer: EditPlayback {
    /// Edited seconds.
    private(set) var currentTime: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var state: EditPlaybackState = .loading
    private(set) var isProcessing = false

    @ObservationIgnored let avPlayer = AVPlayer()
    @ObservationIgnored private let videoURL: URL
    @ObservationIgnored private let editing: TakeEditing
    @ObservationIgnored private var edit: TakeEdit?
    /// What the current item (or the one being built) plays.
    @ObservationIgnored private var itemKey: ItemKey?
    /// Bumped by every rebuild, so a slow build never replaces a newer one.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var buildTask: Task<Void, Never>?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var pendingSeek: TimeInterval?
    @ObservationIgnored private var isSeeking = false
    @ObservationIgnored private var isScrubbing = false
    /// Play again once the seek in progress lands.
    @ObservationIgnored private var resumesAfterSeek = false
    /// New pieces are being built. The item on screen still plays the old ones, whose times no
    /// longer map onto the edit, so it holds still and its ticks are ignored until the new one
    /// is in.
    @ObservationIgnored private var awaitsItem = false

    private static let blankTimeline = EditTimeline(sourceDuration: 0)

    init(videoURL: URL, editing: TakeEditing) {
        self.videoURL = videoURL
        self.editing = editing
        avPlayer.actionAtItemEnd = .pause
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.playerDidTick(time) }
        }
    }

    /// Length of the edit.
    var duration: TimeInterval { edit?.editedDuration ?? 0 }

    /// Where the edit starts inside the item, which begins at the start of the recording.
    private var windowStart: TimeInterval { edit?.timeline.trimStart ?? 0 }

    // MARK: - Edit

    func show(_ edit: TakeEdit) {
        let previous = self.edit
        self.edit = edit
        if let previous, previous.timeline != edit.timeline {
            currentTime = edit.timeline.editedTime(matching: currentTime, in: previous.timeline)
        }
        currentTime = clamped(currentTime)
        applyWindow()
        let key = ItemKey(edit)
        if key != itemKey {
            // A new look or sound waits for the sliders to settle; new pieces show right away.
            let settles = itemKey?.spans == key.spans
            itemKey = key
            if !settles, avPlayer.currentItem != nil {
                awaitsItem = true
                avPlayer.pause()
            }
            rebuild(after: settles ? .milliseconds(250) : nil)
        } else if state == .ready, !awaitsItem, let shown = itemTime, abs(shown - (windowStart + currentTime)) > 0.001 {
            requestSeek(to: currentTime)
        }
    }

    // MARK: - Transport

    func play() {
        guard state == .ready, duration > 0 else { return }
        isPlaying = true
        if currentTime >= duration - 0.02 {
            // From the end, the edit plays again from the start.
            currentTime = 0
            resumesAfterSeek = true
            requestSeek(to: 0)
        } else if isSeeking || awaitsItem {
            resumesAfterSeek = true
        } else {
            avPlayer.play()
        }
    }

    func pause() {
        resumesAfterSeek = false
        isPlaying = false
        avPlayer.pause()
        // The playhead stays on the frame that is showing (the last tick can trail it slightly).
        if state == .ready, !isSeeking, !awaitsItem, let shown = itemTime {
            currentTime = clamped(shown - windowStart)
        }
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func seek(to time: TimeInterval) {
        currentTime = clamped(time)
        requestSeek(to: currentTime)
    }

    func scrub(to time: TimeInterval) {
        if isPlaying { pause() }
        isScrubbing = true
        seek(to: time)
    }

    func endScrub() {
        isScrubbing = false
    }

    func stop() {
        buildTask?.cancel()
        generation += 1
        awaitsItem = false
        resumesAfterSeek = false
        isPlaying = false
        avPlayer.pause()
        if let timeObserver {
            avPlayer.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        avPlayer.replaceCurrentItem(with: nil)
    }

    // MARK: - Item

    private func rebuild(after delay: Duration?) {
        guard let edit else { return }
        buildTask?.cancel()
        generation += 1
        let generation = generation
        var playable = edit
        playable.timeline = edit.timeline.reachable
        buildTask = Task { [weak self, editing, videoURL] in
            if let delay {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            self?.showProcessingIfSlow(generation)
            do {
                let item = try await editing.previewItem(forVideoAt: videoURL, edit: playable)
                self?.install(item, generation: generation)
            } catch {
                self?.buildFailed(generation: generation)
            }
        }
    }

    private func install(_ item: AVPlayerItem, generation: Int) {
        guard generation == self.generation else { return }
        buildTask = nil
        isProcessing = false
        awaitsItem = false
        // Paused while the new item finds the playhead, so it never plays from its start.
        avPlayer.pause()
        resumesAfterSeek = isPlaying
        avPlayer.replaceCurrentItem(with: item)
        state = .ready
        applyWindow()
        requestSeek(to: currentTime)
    }

    private func buildFailed(generation: Int) {
        guard generation == self.generation else { return }
        buildTask = nil
        isProcessing = false
        awaitsItem = false
        // The next change tries again.
        itemKey = nil
        pause()
        avPlayer.replaceCurrentItem(with: nil)
        state = .failed
    }

    /// "Processing…" only when a rebuild is slow enough to notice.
    private func showProcessingIfSlow(_ generation: Int) {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, self.generation == generation, self.buildTask != nil else { return }
            self.isProcessing = true
        }
    }

    /// Holds playback between the handles.
    private func applyWindow() {
        avPlayer.currentItem?.forwardPlaybackEndTime = CMTime(seconds: windowStart + duration, preferredTimescale: 600)
    }

    // MARK: - Time

    /// Seeks exactly to `time` (edited seconds). While one seek runs only the latest target
    /// waits, so a fast drag never piles up requests and the frame keeps up with the finger.
    private func requestSeek(to time: TimeInterval) {
        pendingSeek = time
        guard !isSeeking else { return }
        isSeeking = true
        Task { await runSeeks() }
    }

    private func runSeeks() async {
        while let target = pendingSeek {
            pendingSeek = nil
            // Waiting for new pieces: the new item seeks to the playhead when it's in.
            guard avPlayer.currentItem != nil, !awaitsItem else { continue }
            let time = CMTime(seconds: windowStart + target, preferredTimescale: 600)
            await avPlayer.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        isSeeking = false
        if resumesAfterSeek, !awaitsItem {
            resumesAfterSeek = false
            if isPlaying { avPlayer.play() }
        }
    }

    private func playerDidTick(_ time: CMTime) {
        guard state == .ready, !isSeeking, !isScrubbing, !awaitsItem, time.isNumeric else { return }
        let edited = time.seconds - windowStart
        let reachedEnd = edited >= duration - 0.001
        currentTime = clamped(edited)
        // `forwardPlaybackEndTime` stops playback at the end handle; this is the safety net.
        if reachedEnd, avPlayer.rate != 0 { avPlayer.pause() }
        if isPlaying, avPlayer.rate == 0 || reachedEnd { isPlaying = false }
    }

    private var itemTime: TimeInterval? {
        let time = avPlayer.currentTime()
        return time.isNumeric ? time.seconds : nil
    }

    private func clamped(_ time: TimeInterval) -> TimeInterval {
        min(max(0, time.isFinite ? time : 0), duration)
    }

    /// What an item depends on: the look, the sound and where the pieces join. Not where the
    /// handles are, which only moves the playback window.
    private struct ItemKey: Equatable {
        let recipe: TakeEdit
        let spans: [TimeSpan]

        init(_ edit: TakeEdit) {
            var recipe = edit
            recipe.timeline = QuickEditPlayer.blankTimeline
            recipe.suggestions = []
            self.recipe = recipe
            spans = edit.timeline.reachable.continuousSpans
        }
    }
}
