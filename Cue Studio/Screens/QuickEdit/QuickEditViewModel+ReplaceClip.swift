//
//  QuickEditViewModel+ReplaceClip.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import _PhotosUI_SwiftUI

/// Replace clip (CapCut's way): the picked clip plays another video from Photos, from its start, for as long as the clip
/// lasted, in the same place and with the same speed, zoom, volume, transition and look. Texts, photos and voice-overs on
/// the clip stay on it, at the same moment of the clip. The old recording is never touched, and one Undo brings it back.
/// A shorter video makes the clip as long as the video is.
extension QuickEditViewModel {
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
            replaceClip(id, with: try await mediaImporter.importMedia(item))
        } catch {
            toast.show(String(localized: "Can't add this file"))
        }
    }

    /// Puts `imported` in the clip `id` (see above).
    func replaceClip(_ id: UUID, with imported: ImportedMedia) {
        guard !isClosed, let segment = edit.timeline.segment(id: id) else {
            EditMediaFiles.remove([imported.fileName])
            return
        }
        guard imported.kind == .video, let duration = imported.duration else {
            EditMediaFiles.remove([imported.fileName])
            toast.show(String(localized: "Pick a video first"))
            return
        }
        guard duration >= EditTimeline.minimumClipDuration else {
            EditMediaFiles.remove([imported.fileName])
            toast.show(String(localized: "Video too short to add"))
            return
        }
        importedFiles.insert(imported.fileName)
        let source = ClipSource(fileName: imported.fileName, duration: duration, title: String(localized: "Video"))
        var next = arranged(edit)
        guard let old = next.timeline.replaceSource(ofSegment: id, with: source.id, duration: duration) else { return }
        next.sources.append(source)
        next.moveOverlays(onSegment: id, from: old, to: source.id)
        commit(EditSnapshot(next))
        if let index = next.timeline.index(ofSegment: id) { player.seek(to: next.timeline.editedStart(ofSegmentAt: index)) }
        let shorter = duration + 0.05 < segment.sourceLength
        toast.show(
            shorter
                ? String(localized: "Clip replaced · the video is shorter, so the clip is too")
                : String(localized: "Clip replaced"),
            action: ToastAction(title: String(localized: "Undo")) { [weak self] in self?.undo() }
        )
    }
}
