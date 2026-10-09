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
/// window, so dragging a handle scrubs real frames and nothing is rebuilt. Any other change builds
/// the edit again, one build at a time (the newest edit wins), and the playhead stays on the same
/// moment of the recording. When the build has the same pieces on the same tracks
/// (`CompositionShape`), as after a look, text, caption or volume change, the item stays and only
/// takes the new drawing and mix, so the picture never leaves the screen. New pieces or tracks
/// (a cut, a speed, music, Voice) need a new item: the views hold the picture that was on screen
/// until the new item shows its own.
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

    var isPlaybackBlocked = false {
        didSet {
            guard isPlaybackBlocked, !oldValue else { return }
            pause()
        }
    }

    @ObservationIgnored let avPlayer = AVPlayer()
    @ObservationIgnored private let videoURL: URL
    @ObservationIgnored private let editing: TakeEditing
    @ObservationIgnored private let audioSession: PlaybackAudioSession
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var edit: TakeEdit?
    /// What the current item (or the one being built) plays.
    @ObservationIgnored private var itemKey: ItemKey?
    /// Bumped by every rebuild, so a slow build never replaces a newer one.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var buildTask: Task<Void, Never>?
    /// The edit changed while a build ran: build again as soon as it's in.
    @ObservationIgnored private var rebuildsAfterBuild = false
    /// The views showing the preview, which hold its picture while the item is swapped.
    @ObservationIgnored private var frameHolders: [FrameHolder] = []
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

    init(videoURL: URL, editing: TakeEditing, audioSession: PlaybackAudioSession = PlaybackAudioManager()) {
        self.videoURL = videoURL
        self.editing = editing
        self.audioSession = audioSession
        avPlayer.actionAtItemEnd = .pause
        // Never sent to an AirPlay receiver as video: that doesn't mark the scene as captured, so nothing would hide it
        // (`isPlaybackBlocked`). The sound still follows the audio route.
        avPlayer.allowsExternalPlayback = false
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
            // New pieces: the item on screen can't play them, so it holds still until the new one is
            // in, and a build still running for the old ones is dropped.
            let newPieces = itemKey?.spans != key.spans || itemKey?.speeds != key.speeds || itemKey?.transitions != key.transitions
            itemKey = key
            if newPieces, avPlayer.currentItem != nil {
                awaitsItem = true
                playbackTask?.cancel()
                avPlayer.pause()
            }
            rebuild(restarting: newPieces)
        } else if state == .ready, !awaitsItem, let shown = itemTime, abs(shown - (windowStart + currentTime)) > 0.001 {
            requestSeek(to: currentTime)
        }
    }

    // MARK: - Transport

    func play() {
        guard state == .ready, duration > 0, !isPlaybackBlocked else { return }
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
            startPlayback()
        }
    }

    func pause() {
        playbackTask?.cancel()
        playbackTask = nil
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
        if isPlaying { pause() } else { play() }
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
        playbackTask?.cancel()
        playbackTask = nil
        buildTask?.cancel()
        rebuildsAfterBuild = false
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

    private func startPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        guard !isPlaybackBlocked else { return }
        // Voice-over records while this player runs silently. Do not replace its recording
        // session with an output-only category, or the microphone would stop recording.
        guard !isMuted else {
            avPlayer.play()
            return
        }
        playbackTask = Task { [weak self, audioSession] in
            await audioSession.prepareForPlayback()
            // Capture may have started while the audio session got ready.
            guard !Task.isCancelled, let self, self.isPlaying, !self.isSeeking, !self.awaitsItem, !self.isPlaybackBlocked else { return }
            self.playbackTask = nil
            self.avPlayer.play()
        }
    }

    // MARK: - Frame holders

    func addFrameHolder(_ owner: AnyObject, hold: @escaping @MainActor (CGImage) -> Void) {
        frameHolders.removeAll { $0.owner == nil || $0.owner === owner }
        frameHolders.append(FrameHolder(owner: owner, hold: hold))
    }

    /// Hands the picture on screen to the views right before the item is swapped, so the preview
    /// never goes blank while the new item gets its first frame ready.
    private func holdFrame() {
        frameHolders.removeAll { $0.owner == nil }
        guard !frameHolders.isEmpty,
              let compositor = avPlayer.currentItem?.customVideoCompositor as? CueVideoCompositor,
              let frame = compositor.lastFrame() else { return }
        for holder in frameHolders { holder.hold(frame) }
    }

    /// Builds the item for the edit as it is now. New pieces drop a build still running; a new
    /// look, text or sound lets it finish and builds again right after, so dragging a slider redraws
    /// as fast as builds go without them piling up.
    private func rebuild(restarting: Bool) {
        guard let edit else { return }
        if buildTask != nil, !restarting {
            rebuildsAfterBuild = true
            return
        }
        buildTask?.cancel()
        rebuildsAfterBuild = false
        generation += 1
        let generation = generation
        var playable = edit
        playable.timeline = edit.timeline.reachable
        let window = ItemKey.musicWindow(of: edit)
        buildTask = Task { [weak self, editing, videoURL] in
            self?.showProcessingIfSlow(generation)
            do {
                let item = try await editing.previewItem(forVideoAt: videoURL, edit: playable, window: window)
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
        let wasHeld = awaitsItem
        awaitsItem = false
        if let current = avPlayer.currentItem, let shape = CompositionShape(of: item.asset), shape == CompositionShape(of: current.asset) {
            // The same pieces on the same tracks: only what is drawn or mixed changed. The item
            // stays, so the picture never leaves the screen.
            current.videoComposition = item.videoComposition
            current.audioMix = item.audioMix
            state = .ready
            applyWindow()
            // Playing, the next frames take the new look. Paused, the frame on screen is drawn
            // again; held for new pieces, it plays on from the playhead.
            if !isPlaying || wasHeld {
                resumesAfterSeek = isPlaying
                requestSeek(to: currentTime)
            }
        } else {
            holdFrame()
            // Paused while the new item finds the playhead, so it never plays from its start.
            avPlayer.pause()
            resumesAfterSeek = isPlaying
            avPlayer.replaceCurrentItem(with: item)
            state = .ready
            applyWindow()
            requestSeek(to: currentTime)
        }
        if rebuildsAfterBuild { rebuild(restarting: true) }
    }

    private func buildFailed(generation: Int) {
        guard generation == self.generation else { return }
        buildTask = nil
        isProcessing = false
        awaitsItem = false
        // The next change tries again; one already waiting tries now.
        itemKey = nil
        pause()
        avPlayer.replaceCurrentItem(with: nil)
        state = .failed
        if rebuildsAfterBuild { rebuild(restarting: true) }
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
        if playbackTask != nil {
            playbackTask?.cancel()
            playbackTask = nil
            resumesAfterSeek = isPlaying
        }
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
            if isPlaying { startPlayback() }
        }
    }

    private func playerDidTick(_ time: CMTime) {
        // The safety net while capture holds the preview: whatever started the player (the system, a route change) is stopped
        // on its first tick.
        if isPlaybackBlocked, avPlayer.rate != 0 { avPlayer.pause() }
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

    /// A view showing the preview, for as long as `owner` lives.
    private struct FrameHolder {
        weak var owner: AnyObject?
        let hold: @MainActor (CGImage) -> Void
    }

    /// What an item depends on: the look, the sound, what is laid on top, where the pieces join,
    /// how and at what speed. Not where the handles are, which only moves the playback window.
    private struct ItemKey: Equatable {
        let recipe: TakeEdit
        let spans: [TimeSpan]
        /// One per span: pieces at different speeds never join.
        let speeds: [Double]
        let transitions: [TransitionWindow]
        /// Each piece's sound and zoom (its volume, mute, pitch, zoom and strength): they change
        /// the item like a look does.
        let pieceSettings: [[Double]]
        /// What each piece changes of the take's look (Adjust, Filters, Background): a clip's own
        /// overrides change what the item draws, like the take's look does.
        let clipLooks: [ClipLook?]
        /// Music is placed on the edit's own seconds, so with music the item also depends on where
        /// the edit starts and ends in it.
        let musicWindow: TimeSpan?

        /// Where the edit is in the item, when music needs it.
        static func musicWindow(of edit: TakeEdit) -> TimeSpan? {
            guard !edit.music.isEmpty else { return nil }
            let leadIn = edit.timeline.reachableLeadIn
            return TimeSpan(start: leadIn, end: leadIn + edit.editedDuration)
        }

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
            pieceSettings = edit.timeline.segments.map { segment in
                [
                    segment.volume, segment.isMuted ? 1 : 0, segment.keepsPitch ? 1 : 0,
                    Double(SectionZoom.allCases.firstIndex { $0 == segment.zoom } ?? -1), segment.zoomAmount,
                ]
            }
            clipLooks = edit.timeline.segments.map(\.look)
            musicWindow = Self.musicWindow(of: edit)
        }
    }
}
