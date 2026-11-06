//
//  ClipsViewModel+Cutting.swift
//  Cue Studio
//

import Foundation

/// The clips of the video track: pick one, split it at the playhead (the right part stays
/// picked), duplicate it right after itself or delete it. A video always keeps one clip. Each is
/// one undo step, and a toast says what happened or why it didn't.
extension ClipsViewModel {
    /// Shortest part a split leaves on either side.
    static let minimumSplitPart: TimeInterval = 0.1

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
            toast.show(String(localized: "Move playhead onto the clip"), kind: .problem)
            return
        }
        guard let time = splitPoint(in: index) else {
            toast.show(String(localized: "Move playhead onto the clip"), kind: .problem)
            return
        }
        var next = timeline
        guard next.split(atEdited: time) else {
            toast.show(String(localized: "Move playhead onto the clip"), kind: .problem)
            return
        }
        commit(next)
        selection = .clip(edit.timeline.segments[index + 1].id)
        sayUndoable(String(localized: "Split at \(DurationText.editor(time))"))
    }

    /// Copies a clip right after itself, with what plays on it, and picks the copy with the playhead at its start, as Split does:
    /// its tools (Split, Freeze frame) work on it and the timeline shows where it went.
    func duplicateClip(_ id: UUID) {
        guard isReady, let index = edit.timeline.index(ofSegment: id) else { return }
        duplicateSection(id)
        let segments = edit.timeline.segments
        if segments.indices.contains(index + 1) {
            player.seek(to: edit.timeline.editedStart(ofSegmentAt: index + 1))
            selection = .clip(segments[index + 1].id)
        }
        sayUndoable(String(localized: "\(clipName(at: index)) duplicated after it"))
    }

    /// Takes a clip out of the video (never out of the recording), with what showed only on it (`TakeEdit.removingClip`); the
    /// toast says what went with it, with Undo. The last clip stays.
    func deleteClip(_ id: UUID) {
        guard isReady else { return }
        guard edit.timeline.segments.count > 1 else {
            toast.show(String(localized: "Keep at least one clip"), kind: .problem)
            return
        }
        let name = clipName(at: edit.timeline.index(ofSegment: id) ?? 0)
        guard let removal = edit.removingClip(id) else { return }
        selection = nil
        commit(EditSnapshot(removal.edit))
        Haptics.delete()
        sayUndoable(Self.deletedMessage(name, removal))
    }

    /// "Clip 2 deleted", or "Clip 2 deleted, with 1 text and 2 sounds" when layers went with it.
    static func deletedMessage(_ name: String, _ removal: ClipRemoval) -> String {
        guard !removal.isAlone else { return String(localized: "\(name) deleted") }
        let parts = [
            removal.texts > 0 ? String(localized: "\(removal.texts) texts", comment: "What went with a deleted clip") : nil,
            removal.photos > 0 ? String(localized: "\(removal.photos) photos", comment: "What went with a deleted clip") : nil,
            removal.videos > 0 ? String(localized: "\(removal.videos) videos over it", comment: "What went with a deleted clip") : nil,
            removal.voiceOvers > 0 ? String(localized: "\(removal.voiceOvers) voice-overs", comment: "What went with a deleted clip") : nil,
            removal.sounds > 0 ? String(localized: "\(removal.sounds) sounds", comment: "What went with a deleted clip") : nil,
        ].compactMap(\.self)
        let list = ListFormatter.localizedString(byJoining: parts)
        return String(localized: "\(name) deleted, with \(list)", comment: "Toast: a clip deleted and what went with it (\"1 text and 2 sounds\")")
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
