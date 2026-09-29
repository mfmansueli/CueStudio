//
//  QuickEditViewModel+Media.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import PhotosUI
import SwiftUI

/// Media (B-roll): a photo or video from the library over the take, full screen or in a window
/// the creator places, sizes and crops. Added at the playhead in the free room there (one at a
/// time), shown for 3 seconds (a photo) or its length (a video), then moved or stretched on the
/// media track. The picked file is copied into the app, so the edit never depends on the library.
extension QuickEditViewModel {
    var selectedMedia: MediaOverlay? {
        selectedMediaID.flatMap { id in edit.media.first { $0.id == id } }
    }

    /// Copies the picked photo or video in and adds it at the playhead.
    func importMedia(_ item: PhotosPickerItem) async {
        guard isReady, !isImportingMedia else { return }
        isImportingMedia = true
        defer { isImportingMedia = false }
        do {
            let imported = try await mediaImporter.importMedia(item)
            guard !isClosed else {
                EditMediaFiles.remove([imported.fileName])
                return
            }
            addMedia(imported)
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    /// Adds what was copied in, at the playhead or right after the photo or video already there,
    /// for as long as there's room before the next one.
    func addMedia(_ imported: ImportedMedia) {
        importedFiles.insert(imported.fileName)
        let total = edit.editedDuration
        let wanted = imported.kind == .photo ? MediaOverlay.photoDuration : (imported.duration ?? MediaOverlay.photoDuration)
        let taken = mediaBars.map(\.span)
        var start = player.currentTime
        if let covering = taken.first(where: { $0.contains(start) }) { start = covering.end }
        let next = taken.filter { $0.start >= start - 0.001 }.map(\.start).min() ?? total
        let end = min(start + wanted, next, total)
        guard end - start >= MediaOverlay.minimumDuration else {
            EditMediaFiles.remove([imported.fileName])
            importedFiles.remove(imported.fileName)
            toast.show(String(localized: "No room here — move the playhead to a free spot"))
            return
        }
        let span = edit.timeline.sourceSpan(forEdited: TimeSpan(start: start, end: end))
        let media = MediaOverlay(
            kind: imported.kind, fileName: imported.fileName, aspect: imported.aspect,
            mediaDuration: imported.duration, span: span
        )
        change { $0.media.append(media) }
        selectedMediaID = media.id
        player.pause()
        player.seek(to: start)
        toast.show(imported.kind == .photo ? String(localized: "Photo added") : String(localized: "Video added"))
    }

    func selectMedia(_ id: UUID?) {
        selectedMediaID = selectedMediaID == id ? nil : id
        if let id, let bar = mediaBars.first(where: { $0.id == id }), !bar.span.contains(player.currentTime) {
            player.pause()
            player.seek(to: bar.span.start)
        }
    }

    func updateMedia(_ id: UUID, _ update: (inout MediaOverlay) -> Void) {
        change { snapshot in
            guard let index = snapshot.media.firstIndex(where: { $0.id == id }) else { return }
            update(&snapshot.media[index])
        }
    }

    func deleteMedia(_ id: UUID) {
        change { $0.media.removeAll { $0.id == id } }
        toast.show(String(localized: "Media removed"))
    }

    /// The photo or video showing at the playhead, for the preview's handles.
    var visibleMedia: MediaOverlay? {
        let time = player.currentTime
        guard let bar = mediaBars.first(where: { $0.span.contains(time) }) else { return nil }
        return edit.media.first { $0.id == bar.id }
    }

    /// Its place on a preview of `size` (from the top left), as the export places it.
    func frame(ofMedia media: MediaOverlay, in size: CGSize) -> CGRect {
        MediaPlacement.rect(for: media, in: size)
    }
}
