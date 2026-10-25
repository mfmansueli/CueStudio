//
//  ClipsViewModel+ReplaceClip.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import _PhotosUI_SwiftUI

/// Replace clip (CapCut's way): the picked clip plays another video from Photos, for as long as the clip lasted, in the same
/// place and with the same speed, zoom, volume, transition and look; a video longer than the clip first asks which part of it
/// fills the clip (`MediaPartSheet`). Texts, photos and voice-overs on the clip stay on it, at the same moment of the clip.
/// The old recording is never touched, and one Undo brings it back. A shorter video makes the clip as long as the video is.
extension ClipsViewModel {
    /// Clip › Replace: asks Photos for a video.
    func askToReplaceClip() {
        guard isReady, let id = selection?.clipID else { return }
        player.pause()
        requestPhoto(.replaceClip(id))
    }

    /// Copies the picked video in and puts it in the clip.
    func replaceClip(_ id: UUID, importing item: PhotosPickerItem) async {
        guard isReady, !isImportingMedia else { return }
        isImportingMedia = true
        defer { isImportingMedia = false }
        do {
            let imported = try await importPicked(item)
            if let segment = edit.timeline.segment(id: id), imported.kind == .video, let length = imported.duration,
               length > segment.sourceLength + 0.05 {
                importedFiles.insert(imported.fileName)
                partChoice = MediaPartChoice(purpose: .replaceClip(id), pick: MediaPick(imported), length: segment.sourceLength)
            } else {
                replaceClip(id, with: imported)
            }
        } catch is CancellationError {
            // Cancel on the pill, or the editor closed: nothing to say.
        } catch {
            noteFailure(error, "replaceClip")
            toast.show(String(localized: "Can't add this file"), kind: .problem)
        }
    }

    /// Puts `imported` in the clip `id` (see above), from `start` (seconds of the new video).
    func replaceClip(_ id: UUID, with imported: ImportedMedia, from start: TimeInterval = 0) {
        guard !isClosed, let segment = edit.timeline.segment(id: id) else {
            EditMediaFiles.remove([imported.fileName])
            return
        }
        guard imported.kind == .video, let duration = imported.duration else {
            EditMediaFiles.remove([imported.fileName])
            toast.show(String(localized: "Pick a video first"), kind: .problem)
            return
        }
        guard duration >= EditTimeline.minimumClipDuration else {
            EditMediaFiles.remove([imported.fileName])
            toast.show(String(localized: "Video too short to add"), kind: .problem)
            return
        }
        importedFiles.insert(imported.fileName)
        let source = ClipSource(fileName: imported.fileName, duration: duration, title: String(localized: "Video"))
        var next = arranged(edit)
        let before = next.timeline
        guard let old = next.timeline.replaceSource(ofSegment: id, with: source.id, duration: duration, from: start) else { return }
        next.sources.append(source)
        next.moveOverlays(onSegment: id, from: old, to: source.id, start: next.timeline.segment(id: id)?.sourceStart ?? 0, in: before)
        commit(EditSnapshot(next))
        if let index = next.timeline.index(ofSegment: id) { player.seek(to: next.timeline.editedStart(ofSegmentAt: index)) }
        let shorter = duration - start + 0.05 < segment.sourceLength
        toast.show(
            shorter
                ? String(localized: "Clip replaced · the video is shorter, so the clip is too")
                : String(localized: "Clip replaced"),
            action: undoAction
        )
    }
}
