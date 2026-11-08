//
//  LookViewModel+Cutout.swift
//  Cue Studio
//

import Foundation

/// The cut-out creator: where they stand over a new background (moved on the preview, resized by Size or a pinch, one undo step a
/// gesture), and Check the cutout, which reads the recordings the automatic cutout is used on and lists the moments where Vision loses
/// the creator for longer than their last outline is held, each one a tap away. Both belong to Background's recording or clip, like
/// the rest of the background.
extension LookViewModel {
    // MARK: - Place

    /// A photo or video shown Behind you at the playhead.
    var behindAtPlayhead: MediaOverlay? {
        let time = player.currentTime
        return edit.placedMedia(in: edit.timeline).first { entry in
            entry.media.layout == .behind && entry.pieces.contains { $0.edited.start - 0.000_1 <= time && time < $0.edited.end }
        }?.media
    }

    /// Whether the creator can be moved and resized now: something new is behind them (a blur, a color, a photo, or a photo or video
    /// Behind you).
    var canPlacePerson: Bool {
        currentBackground.isActive || behindAtPlayhead != nil
    }

    var personPlacement: PersonPlacement { currentBackground.placement }

    /// Moves or resizes the creator (an undo step, or part of the gesture's); back where they were recorded keeps nothing.
    func setPersonPlacement(_ placement: PersonPlacement) {
        let kept = placement.kept
        updateBackground { $0.person = kept.isAsRecorded ? nil : kept }
    }

    func resetPersonPlacement() {
        guard currentBackground.movesPerson else { return }
        updateBackground { $0.person = nil }
        announce(String(localized: "Back where you were recorded"))
    }

    // MARK: - Check the cutout

    /// What Check the cutout says now: what it found, while the edit is the one it read; else nothing yet.
    var shownCutoutCheck: CutoutCheckState {
        if case .checked(_, let signature) = cutoutCheck, signature != cutoutCheckSignature { return .idle }
        return cutoutCheck
    }

    /// Whether there is something to check: this iPhone finds people, and the automatic cutout is used somewhere.
    var canCheckCutout: Bool {
        canFindPeople != false && !cutoutCheckParts.isEmpty
    }

    /// What the check depends on: the clips, the backgrounds and what shows Behind you.
    var cutoutCheckSignature: Int {
        var hasher = Hasher()
        hasher.combine(edit.timeline)
        hasher.combine(edit.backgrounds)
        hasher.combine(edit.media.filter { $0.layout == .behind })
        return hasher.finalize()
    }

    /// One stretch of a recording to read, and where it plays in the edit.
    struct CutoutCheckPart {
        let url: URL
        let segment: EditSegment
        let editedStart: TimeInterval
    }

    /// The clips the automatic cutout is used on: their background cuts the creator out of it, or a photo or video shows Behind them.
    var cutoutCheckParts: [CutoutCheckPart] {
        let behind = edit.placedMedia(in: edit.timeline).filter { $0.media.layout == .behind }.flatMap { $0.pieces.map(\.edited) }
        var parts: [CutoutCheckPart] = []
        var elapsed: TimeInterval = 0
        for segment in edit.timeline.segments {
            defer { elapsed += segment.duration }
            let effect = segment.look?.background ?? edit.backgrounds.first { $0.sourceID == segment.sourceID }?.effect ?? BackgroundEffect()
            guard effect.cutout == .person else { continue }
            let shown = TimeSpan(start: elapsed, end: elapsed + segment.duration)
            guard effect.isActive || behind.contains(where: { $0.overlaps(shown) }) else { continue }
            let url = segment.sourceID.flatMap { id in edit.sources.first { $0.id == id } }.map { EditMediaFiles.url(for: $0.fileName) }
                ?? session.videoURL
            parts.append(CutoutCheckPart(url: url, segment: segment, editedStart: elapsed))
        }
        return parts
    }

    /// Reads every clip the cutout is used on, one after the other; the moments found are in edited seconds. Asking again while it
    /// reads does nothing.
    func checkCutout() {
        guard cutoutCheckTask == nil else { return }
        let parts = cutoutCheckParts
        guard !parts.isEmpty else { return }
        let signature = cutoutCheckSignature
        let checker = cutoutChecker
        let total = max(0.001, parts.reduce(0) { $0 + $1.segment.sourceLength })
        cutoutCheck = .checking(progress: 0)
        cutoutCheckTask = Task { [weak self] in
            var misses: [TimeSpan] = []
            var done: TimeInterval = 0
            do {
                for part in parts {
                    let before = done
                    let length = part.segment.sourceLength
                    let report = self?.checkProgress(from: before, length: length, of: total) ?? { @Sendable _ in }
                    let result = try await checker.check(videoAt: part.url, over: part.segment.span, progress: report)
                    done += length
                    misses += result.failures.compactMap { failure -> TimeSpan? in
                        let from = max(part.segment.sourceStart, failure.start), until = min(part.segment.sourceEnd, failure.end)
                        guard until > from else { return nil }
                        return TimeSpan(
                            start: part.editedStart + part.segment.editedOffset(forSource: from - part.segment.sourceStart),
                            end: part.editedStart + part.segment.editedOffset(forSource: until - part.segment.sourceStart)
                        )
                    }
                }
                guard let self, !self.isClosed, !Task.isCancelled else { return }
                self.cutoutCheckTask = nil
                self.cutoutCheck = .checked(misses: misses.sorted { $0.start < $1.start }, of: signature)
                self.announce(misses.isEmpty
                    ? String(localized: "Found you in every frame")
                    : String(localized: "Cue lost you in \(misses.count) moments"))
            } catch {
                // Stop already put it back as it was.
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.noteFailure(error, "checkCutout")
                self?.cutoutCheck = .failed
            }
            if !Task.isCancelled { self?.cutoutCheckTask = nil }
        }
    }

    /// Hands how far one part got (0 to 1) to the panel, as a share of every part to read.
    private func checkProgress(from before: TimeInterval, length: TimeInterval, of total: TimeInterval) -> @Sendable (Double) -> Void {
        { [weak self] fraction in
            guard let self else { return }
            Task { @MainActor in
                guard case .checking = self.cutoutCheck else { return }
                self.cutoutCheck = .checking(progress: min(1, (before + fraction * length) / total))
            }
        }
    }

    /// Stop, while it reads: nothing is kept.
    func cancelCutoutCheck() {
        cutoutCheckTask?.cancel()
        cutoutCheckTask = nil
        cutoutCheck = .idle
    }

    /// Go there: the playhead at a moment the check found, paused, to look at it.
    func goToCutoutMiss(_ miss: TimeSpan) {
        player.pause()
        player.seek(to: min(miss.end, miss.start + 0.05))
    }
}
