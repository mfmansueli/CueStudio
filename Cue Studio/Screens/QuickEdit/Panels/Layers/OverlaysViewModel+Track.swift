//
//  OverlaysViewModel+Track.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// Track: the picked text, graphic or photo follows what's under it in the video. The object under the item's center at the
/// playhead is followed through the clip under the playhead (forwards and backwards, as long as the item shows there) with
/// Vision (`ObjectTracking`), and the path becomes keyframes the creator can edit (`TrackedMotion`), in one undo step. Where the
/// object is lost (it left the frame, something covered it), the item holds from there.
extension OverlaysViewModel {
    /// How big the followed box is, as a share of the video's width.
    static let trackedBoxSide = 0.14

    var isTracking: Bool { trackingProgress != nil }

    /// "Tracking · 40%" while it runs.
    var trackingLabel: String? {
        trackingProgress.map { String(localized: "Tracking · \(Int(($0 * 100).rounded()))%") }
    }

    func trackSelectedItem() {
        guard !isTracking, let item = motionItem else { return }
        guard let span = editedSpan(of: item), localTime(of: item) != nil else {
            toast.show(String(localized: "Move playhead onto it first"))
            return
        }
        player.pause()
        let playhead = min(player.currentTime, span.end - 0.001)
        let timeline = edit.timeline
        let index = timeline.segmentIndex(atEdited: playhead)
        let segment = timeline.segments[index]
        let clipStart = timeline.editedStart(ofSegmentAt: index)
        // Within the clip under the playhead, as long as the item shows there.
        let from = max(span.start, clipStart), until = min(span.end, clipStart + segment.duration)
        let url = segment.sourceID.flatMap { id in edit.sources.first { $0.id == id } }.map { EditMediaFiles.url(for: $0.fileName) } ?? videoURL
        let center = motionState(of: item).center
        let edit = edit
        trackingProgress = 0
        Haptics.selection()
        jobs.start(.tracking) { [weak self, tracker] ticket in
            guard let placement = await Self.placement(for: url, in: edit, steadiedBy: segment.stabilization) else {
                self?.trackingFinished(ticket, nil, item: item, span: span, timeline: timeline)
                return
            }
            let sourceAt = segment.sourceStart + segment.sourceOffset(forEdited: playhead - clipStart)
            let start = placement.recordingPoint(for: center, at: sourceAt)
            let size = placement.recordingSize(forVideoWidth: Self.trackedBoxSide)
            let box = NormalizedBox(center: start, width: size.width, height: size.height)
            let report: @Sendable (Double, Bool) -> Void = { done, forward in
                Task { @MainActor in
                    guard let self, self.jobs.isCurrent(ticket) else { return }
                    // Forwards first (to the item's end), then backwards: each half of the bar.
                    self.trackingProgress = min(1, (forward ? 0 : 0.5) + done / 2)
                }
            }
            do {
                let sourceEnd = segment.sourceStart + segment.sourceOffset(forEdited: until - clipStart)
                let sourceFrom = segment.sourceStart + segment.sourceOffset(forEdited: from - clipStart)
                let ahead = try await tracker.track(videoAt: url, box: box, at: sourceAt, until: sourceEnd) { report($0, true) }
                let behind = try await tracker.track(videoAt: url, box: box, at: sourceAt, until: sourceFrom) { report($0, false) }
                let samples = (behind + ahead.dropFirst()).sorted { $0.time < $1.time }
                let points = samples.map { sample in
                    TrackedMotion.Point(
                        time: clipStart + segment.editedOffset(forSource: sample.time - segment.sourceStart) - span.start,
                        center: placement.videoPoint(for: sample.box.center, at: sample.time)
                    )
                }
                self?.trackingFinished(
                    ticket, points, item: item, span: span, timeline: timeline, reached: (from - span.start)...(until - span.start)
                )
            } catch {
                self?.noteFailure(error, "track")
                self?.trackingFinished(ticket, nil, item: item, span: span, timeline: timeline)
            }
        }
    }

    func cancelTracking() {
        jobs.cancel(.tracking)
        trackingProgress = nil
    }

    /// The tracked path on the item as keyframes, in one step: the keyframes it had inside the tracked part give way, the
    /// others stay. Dropped when the run was cancelled (a new one may have started meanwhile), the editor closed, or the
    /// video or the item moved while it ran (the path was measured on what they were).
    private func trackingFinished(
        _ ticket: EditorJobs.Ticket, _ points: [TrackedMotion.Point]?, item: MotionItem, span: TimeSpan, timeline: EditTimeline,
        reached: ClosedRange<TimeInterval> = 0...0
    ) {
        guard jobs.isCurrent(ticket) else { return }
        trackingProgress = nil
        guard edit.timeline == timeline, editedSpan(of: item) == span else {
            toast.show(String(localized: "The video changed meanwhile · Track it again"))
            return
        }
        guard let points, points.count > 1, let first = points.first, let last = points.last else {
            toast.show(String(localized: "Couldn’t follow anything there · Put it on what it should follow"))
            return
        }
        let base = OverlayMotion.State(center: motionState(of: item).center, scale: 1, opacity: 1)
        let motion = OverlayMotion(keyframes(of: item))
        let tracked = TrackedMotion.keyframes(for: points) { time in
            let state = motion.state(at: time) ?? base
            return (state.scale, state.opacity)
        }
        updateKeyframes(of: item) { keyframes in
            keyframes.removeAll { $0.time >= first.time - OverlayKeyframe.sameMoment && $0.time <= last.time + OverlayKeyframe.sameMoment }
            keyframes += tracked
        }
        let lost = last.time < reached.upperBound - 0.2 || first.time > reached.lowerBound + 0.2
        toast.show(lost
            ? String(localized: "Lost it after \(DurationText.tenths(last.time - first.time)) · It holds from there")
            : String(localized: "Tracked · \(tracked.count) keyframes to adjust"))
    }

    /// How the recording at `url` lands on the edit's frame (Stabilize's correction, its crop, Follow face's path, or Fit). Off
    /// the main thread: it reads the recording's analysis.
    @concurrent
    private nonisolated static func placement(for url: URL, in edit: TakeEdit, steadiedBy level: StabilizationLevel?) async -> FramePlacement? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (natural, transform) = try? await track.load(.naturalSize, .preferredTransform) else { return nil }
        let rect = CGRect(origin: .zero, size: natural).applying(transform)
        let size = CGSize(width: abs(rect.width), height: abs(rect.height))
        let crop = CropMath.crop(in: size, aspect: edit.aspect.widthOverHeight, offset: edit.cropOffset)
        var placement = FramePlacement(uprightSize: size, crop: crop, fits: edit.cropFit == .fit)
        placement.steady = level.flatMap { MotionAnalysisStore.stabilizationPath(forRecording: url, level: $0) }
        if edit.faceFollow != nil, edit.cropFit == .fill {
            let coreImageCrop = CGRect(x: crop.minX, y: size.height - crop.maxY, width: crop.width, height: crop.height)
            placement.follow = EditedComposition.followPath(
                for: edit, analysis: MotionAnalysisStore.complete(forRecording: url), crop: coreImageCrop, size: size
            )
        }
        return placement
    }
}
