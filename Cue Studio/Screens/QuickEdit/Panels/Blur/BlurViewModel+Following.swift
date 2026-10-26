//
//  BlurViewModel+Following.swift
//  Cue Studio
//

import Foundation
import os

/// Following a Blur area's subject: a face (tapped, or an area drawn over most of one) through the recording's motion analysis
/// (the same faces Follow face reads, ten a second, nothing analyzed again), anything else (or a face the analysis doesn't
/// reach) with Vision's tracker from the
/// playhead, forwards then backwards. The path lands as the area's keyframes in one undo step, on the footage's own seconds,
/// so a cut, a speed change or a new crop later never needs it followed again. Cancel keeps what was followed until then
/// and marks the rest. "Track from here" follows only the stretch left unchecked under the playhead, from where the creator
/// put the area back on its subject, until it meets the part that was right.
extension BlurViewModel {
    /// Following or not.
    var isFollowing: Bool { following != nil }

    /// "Tracking · 40%" while it runs.
    var followingLabel: String? {
        following.map { String(localized: "Tracking · \(Int(($0.progress * 100).rounded()))%") }
    }

    /// Follows the area (the picked one by default) across all of it, from the playhead when it's on it.
    func follow(_ id: UUID? = nil) {
        startFollowing(id ?? selectedBlurID, onlyUnchecked: false)
    }

    /// Follows the unchecked stretch under the playhead from here (else, the whole area from here).
    func followFromHere() {
        startFollowing(selectedBlurID, onlyUnchecked: true)
    }

    /// Stops following where it is: what was followed stays, the rest is marked; the areas waiting their turn don't start.
    func cancelFollowing() {
        followQueue = []
        stopFlag.withLock { $0 = true }
    }

    // MARK: - Running

    private func startFollowing(_ id: UUID?, onlyUnchecked: Bool) {
        guard isReady, let id, let region = edit.blurRegions.first(where: { $0.id == id }) else { return }
        // One area at a time: another waits its turn instead of stopping the one running (whose path would be lost).
        if let running = following?.id {
            if running != id, !followQueue.contains(id) { followQueue.append(id) }
            return
        }
        if edit.isOnPhoto(region) {
            toast.show(String(localized: "A photo doesn't move · Nothing to track"), kind: .problem)
            return
        }
        guard let url = url(of: region.target) else { return }
        player.pause()
        // From where the creator sees it on what it hides: the playhead must be on it.
        guard let here = edit.footageTime(of: region.target, at: player.currentTime, in: edit.timeline),
              region.span.start - BlurFollowing.frame <= here, here <= region.span.end + BlurFollowing.frame else {
            toast.show(String(localized: "Move playhead onto it first"), kind: .problem)
            return
        }
        let start = min(max(here, region.span.start), region.span.end)
        var range = region.span
        if onlyUnchecked, let stretch = region.openUnchecked.first(where: { $0.start - 0.05 <= start && start <= $0.end + 0.05 }) {
            range = TimeSpan(start: max(region.span.start, stretch.start - BlurFollowing.frame), end: min(region.span.end, stretch.end + BlurFollowing.frame))
        }
        let box = region.box(at: start)
        // A face through the analysis: a tapped one, and an area drawn over most of a face (the creator's size kept, the face's
        // path followed). Anything else, or part of a face (the eyes, a mouth), with Vision's tracker.
        let byFace = !region.target.isMedia
        stopFlag.withLock { $0 = false }
        following = (id, 0)
        Haptics.selection()
        jobs.start(.blurFollowing) { [weak self, tracker, stopFlag] ticket in
            var result: BlurFollowing.Result?
            if byFace, let samples = await Self.faceSamples(of: url, covering: range),
               let face = BlurFollowing.faces(in: samples, at: start).filter({ box.sharedArea(with: $0) > $0.area * 0.5 }).max(by: { $0.area < $1.area }) {
                result = BlurFollowing.followFace(samples, area: box, face: face, at: start, through: range)
            }
            if result == nil {
                let report: @Sendable (Double, Bool) -> Void = { done, forward in
                    Task { @MainActor in
                        guard let self, self.jobs.isCurrent(ticket) else { return }
                        // Forwards first, then backwards: each half of the bar.
                        self.following = (id, min(1, (forward ? 0 : 0.5) + done / 2))
                    }
                }
                let stop: @Sendable () -> Bool = { stopFlag.withLock { $0 } }
                let tracked = NormalizedBox(center: box.center, width: max(0.04, box.width), height: max(0.04, box.height))
                do {
                    let ahead = try await tracker.track(videoAt: url, box: tracked, at: start, until: range.end, shouldStop: stop) { report($0, true) }
                    // From its first moment there's nothing behind to follow.
                    let behind = start > range.start + BlurFollowing.frame
                        ? try await tracker.track(videoAt: url, box: tracked, at: start, until: range.start, shouldStop: stop) { report($0, false) }
                        : []
                    result = BlurFollowing.followObject(
                        ahead: ahead, behind: Array(behind.dropLast()), area: box, tracked: tracked, at: start, through: range
                    )
                } catch {
                    self?.noteFailure(error, "blurFollow")
                }
            }
            self?.followingFinished(ticket, id: id, result: result)
        }
    }

    private func followingFinished(_ ticket: EditorJobs.Ticket, id: UUID, result: BlurFollowing.Result?) {
        guard jobs.isCurrent(ticket) else { return }
        following = nil
        // Deleted meanwhile: nothing to put it on; the next one waiting goes on.
        guard edit.blurRegions.contains(where: { $0.id == id }) else {
            if !followQueue.isEmpty { follow(followQueue.removeFirst()) }
            return
        }
        guard let result else {
            // Nothing tracked it: all of it may not cover what it hides, and it says so until it's tracked or checked.
            update(id) { area in
                area.isFollowed = true
                area.markUnchecked(area.span)
            }
            toast.show(String(localized: "Couldn’t track it here · Move it onto what it hides"), kind: .problem)
            if !followQueue.isEmpty { follow(followQueue.removeFirst()) }
            return
        }
        change { snapshot in
            guard var regions = snapshot.blurRegions, let index = regions.firstIndex(where: { $0.id == id }) else { return }
            regions[index] = BlurFollowing.applying(result, to: regions[index])
            snapshot.blurRegions = regions
        }
        if let region = edit.blurRegions.first(where: { $0.id == id }) {
            if region.isCovered {
                toast.show(String(localized: "Tracked the whole time"), kind: .cue)
            } else {
                let left = DurationText.tenths(region.uncheckedDuration)
                toast.show(String(localized: "Not tracked for \(left) · Check the marked part"), kind: .problem)
            }
        }
        if !followQueue.isEmpty { follow(followQueue.removeFirst()) }
    }

    /// The recording's face samples across `range`, when its motion analysis reached that far.
    @concurrent
    private nonisolated static func faceSamples(of url: URL, covering range: TimeSpan) async -> [SubjectSample]? {
        guard let analysis = MotionAnalysisStore.load(forRecording: url), analysis.isCurrent,
              analysis.analyzedUntil >= min(range.end, analysis.duration) - 0.05 else { return nil }
        return analysis.subjects.filter { $0.time >= range.start - 0.2 && $0.time <= range.end + 0.2 }
    }
}
