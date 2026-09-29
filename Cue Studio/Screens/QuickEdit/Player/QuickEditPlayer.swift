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
    var reviewedPart: ClosedRange<TimeInterval>? {
        didSet {
            guard reviewedPart != oldValue else { return }
            stopTime = isPlaying ? reviewedPart.flatMap { currentTime < $0.upperBound ? $0.upperBound : nil } : nil
            applyWindow()
        }
    }

    var isMuted = false {
        didSet { avPlayer.isMuted = isMuted }
    }

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
    /// Where this playback stops short of the end: the end of the part under review, when it
    /// started before it. Set by `play()`, cleared when playback stops.
    @ObservationIgnored private var stopTime: TimeInterval?

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

    /// Edited seconds where playback stops: the end of the part under review, or of the edit.
    private var playbackEnd: TimeInterval { min(stopTime ?? duration, duration) }

    /// Where the edit starts inside the item, which begins at the start of the recording (played
    /// at the first piece's speed).
    private var windowStart: TimeInterval { edit?.timeline.reachableLeadIn ?? 0 }

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
            let settles = itemKey?.spans == key.spans && itemKey?.speeds == key.speeds && itemKey?.transitions == key.transitions
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
        var from = currentTime
        if let part = reviewedPart, abs(currentTime - part.upperBound) < 0.02 {
            // From the end of the part under review, that part plays again.
            from = part.lowerBound
        } else if currentTime >= duration - 0.02 {
            // From the end, the edit plays again from the start.
            from = 0
        }
        stopTime = reviewedPart.flatMap { from < $0.upperBound - 0.02 ? $0.upperBound : nil }
        applyWindow()
        if from != currentTime {
            currentTime = from
            resumesAfterSeek = true
            requestSeek(to: from)
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
            currentTime = min(clamped(shown - windowStart), playbackEnd)
        }
        endStop()
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
        stopTime = nil
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

    /// Holds playback between the handles, or up to the end of the part under review.
    private func applyWindow() {
        avPlayer.currentItem?.forwardPlaybackEndTime = CMTime(seconds: windowStart + playbackEnd, preferredTimescale: 600)
    }

    /// Playback is over: the next one runs to the end handle unless it starts inside a part.
    private func endStop() {
        guard stopTime != nil else { return }
        stopTime = nil
        applyWindow()
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
        let end = playbackEnd
        let reachedEnd = edited >= end - 0.001
        currentTime = min(clamped(edited), end)
        // `forwardPlaybackEndTime` stops playback at the end handle (or the end of the part under
        // review); this is the safety net.
        if reachedEnd, avPlayer.rate != 0 { avPlayer.pause() }
        guard isPlaying, avPlayer.rate == 0 || reachedEnd else { return }
        isPlaying = false
        guard stopTime != nil else { return }
        endStop()
        // The part under review ends exactly on its end: never a frame past it, nor one short.
        if abs(edited - end) < 0.05 {
            currentTime = end
            if edited != end { requestSeek(to: end) }
        }
    }

    private var itemTime: TimeInterval? {
        let time = avPlayer.currentTime()
        return time.isNumeric ? time.seconds : nil
    }

    private func clamped(_ time: TimeInterval) -> TimeInterval {
        min(max(0, time.isFinite ? time : 0), duration)
    }

    /// What an item depends on: the look, the sound, what is laid on top, where the pieces join,
    /// how and at what speed. Not where the handles are, which only moves the playback window.
    private struct ItemKey: Equatable {
        let recipe: TakeEdit
        let spans: [TimeSpan]
        /// One per span: pieces at different speeds never join.
        let speeds: [Double]
        let transitions: [TransitionWindow]

        init(_ edit: TakeEdit) {
            var recipe = edit
            recipe.timeline = QuickEditPlayer.blankTimeline
            recipe.suggestions = []
            // The cover is drawn apart from the video.
            recipe.cover = nil
            self.recipe = recipe
            let reachable = edit.timeline.reachable
            var spans: [TimeSpan] = []
            var speeds: [Double] = []
            for (index, segment) in reachable.segments.enumerated() {
                if reachable.isSeamless(index) {
                    spans[spans.count - 1].end = segment.sourceEnd
                } else {
                    spans.append(segment.span)
                    speeds.append(segment.speed)
                }
            }
            self.spans = spans
            self.speeds = speeds
            transitions = TransitionWindow.windows(in: reachable)
        }
    }
}
