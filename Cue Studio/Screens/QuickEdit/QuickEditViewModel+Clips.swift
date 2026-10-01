//
//  QuickEditViewModel+Clips.swift
//  Cue Studio
//

import Foundation

/// The clips of the video track: pick one, split it at the playhead (the right part stays
/// picked), duplicate it right after itself or delete it. A video always keeps one clip. Each is
/// one undo step, and a toast says what happened or why it didn't.
extension QuickEditViewModel {
    /// Shortest part a split leaves on either side.
    static let minimumSplitPart: TimeInterval = 0.1

    /// The clip under the playhead.
    var clipIndexAtPlayhead: Int {
        edit.timeline.segmentIndex(atEdited: player.currentTime)
    }

    /// Whether the playhead is inside the picked clip, far enough from its ends to split it.
    var canSplitSelectedClip: Bool {
        guard let id = selection?.clipID, let index = edit.timeline.index(ofSegment: id) else { return false }
        return splitPoint(in: index) != nil
    }

    /// "Edit" on the main toolbar: picks the clip under the playhead.
    func selectClipAtPlayhead() {
        let segments = edit.timeline.segments
        guard segments.indices.contains(clipIndexAtPlayhead) else { return }
        toolMenu = nil
        selection = .clip(segments[clipIndexAtPlayhead].id)
    }

    /// Splits the picked clip (or the one under the playhead) at the playhead and picks the right
    /// part, ready to delete.
    func splitClip() {
        guard isReady else { return }
        player.pause()
        let timeline = edit.timeline
        let index = clipIndexAtPlayhead
        if let id = selection?.clipID, timeline.index(ofSegment: id) != index {
            toast.show(String(localized: "Move the playhead over this clip"))
            return
        }
        guard let time = splitPoint(in: index) else {
            toast.show(String(localized: "Move the playhead inside the clip"))
            return
        }
        var next = timeline
        guard next.split(atEdited: time) else {
            toast.show(String(localized: "Move the playhead inside the clip"))
            return
        }
        commit(next)
        selection = .clip(edit.timeline.segments[index + 1].id)
        toast.show(String(localized: "Split at \(DurationText.editor(time))"))
    }

    /// Copies a clip right after itself, with what plays on it, and picks the copy.
    func duplicateClip(_ id: UUID) {
        guard isReady, let index = edit.timeline.index(ofSegment: id) else { return }
        duplicateSection(id)
        let segments = edit.timeline.segments
        if segments.indices.contains(index + 1) { selection = .clip(segments[index + 1].id) }
        toast.show(String(localized: "Clip duplicated"))
    }

    /// Takes a clip out of the video (never out of the recording). The last clip stays.
    func deleteClip(_ id: UUID) {
        guard isReady else { return }
        guard edit.timeline.segments.count > 1 else {
            toast.show(String(localized: "A video needs at least one clip"))
            return
        }
        var next = edit.timeline
        guard next.removeSegment(id: id) else { return }
        selection = nil
        commit(next)
        Haptics.delete()
        toast.show(String(localized: "Clip deleted — tap Undo to bring it back"))
    }

    // MARK: - Private

    /// The playhead, when it is inside the clip at `index` with room on both sides.
    private func splitPoint(in index: Int) -> TimeInterval? {
        let timeline = edit.timeline
        guard timeline.segments.indices.contains(index) else { return nil }
        let time = player.currentTime
        let start = timeline.editedStart(ofSegmentAt: index)
        let end = start + timeline.segments[index].duration
        guard time - start >= Self.minimumSplitPart, end - time >= Self.minimumSplitPart else { return nil }
        return time
    }
}
