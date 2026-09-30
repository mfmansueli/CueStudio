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

    /// Adds what was copied in at the playhead, on top of what's there, for its length (a photo's
    /// three seconds) or until the end. Up to `MediaOverlay.simultaneousLimit` show at once.
    func addMedia(_ imported: ImportedMedia) {
        importedFiles.insert(imported.fileName)
        let total = edit.editedDuration
        let wanted = imported.kind == .photo ? MediaOverlay.photoDuration : (imported.duration ?? MediaOverlay.photoDuration)
        let start = min(player.currentTime, max(0, total - MediaOverlay.minimumDuration))
        let end = min(start + wanted, total)
        let placed = TimeSpan(start: start, end: end)
        guard end - start >= MediaOverlay.minimumDuration else {
            EditMediaFiles.remove([imported.fileName])
            importedFiles.remove(imported.fileName)
            toast.show(String(localized: "No room here — move the playhead to a free spot"))
            return
        }
        guard LayerLanes.peak(of: mediaBars.map(\.span), within: placed) < MediaOverlay.simultaneousLimit else {
            EditMediaFiles.remove([imported.fileName])
            importedFiles.remove(imported.fileName)
            toast.show(String(localized: "Up to 3 photos or videos at once here"))
            return
        }
        let pinned = edit.pin(placed)
        var media = MediaOverlay(
            kind: imported.kind, fileName: imported.fileName, aspect: imported.aspect,
            mediaDuration: imported.duration, span: pinned.span
        )
        media.clipAnchor = pinned.anchor
        media.layer = (edit.media.map(\.stackOrder).max() ?? -1) + 1
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

    /// Moves a photo or video one step up (over the one above it) or down, in one undo step.
    func restack(_ id: UUID, up: Bool) {
        change { snapshot in
            // Normalize the order first (media from before stacking share the bottom).
            let ordered = snapshot.media.enumerated().sorted { ($0.element.stackOrder, $0.offset) < ($1.element.stackOrder, $1.offset) }.map(\.element.id)
            guard let position = ordered.firstIndex(of: id) else { return }
            let target = up ? position + 1 : position - 1
            guard ordered.indices.contains(target) else { return }
            var order = ordered
            order.swapAt(position, target)
            for (layer, mediaID) in order.enumerated() {
                if let index = snapshot.media.firstIndex(where: { $0.id == mediaID }) { snapshot.media[index].layer = layer }
            }
        }
    }

    /// Whether the picked photo or video can go up (or down) a step.
    func canRestack(_ id: UUID, up: Bool) -> Bool {
        let ordered = edit.media.enumerated().sorted { ($0.element.stackOrder, $0.offset) < ($1.element.stackOrder, $1.offset) }.map(\.element.id)
        guard let position = ordered.firstIndex(of: id) else { return false }
        return up ? position < ordered.count - 1 : position > 0
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
        let placed = MediaPlacement.rect(for: media, in: size)
        guard media.keyframes?.isEmpty == false else { return placed }
        // Where its keyframes have it at the playhead.
        let state = motionState(of: .media(media.id))
        let width = placed.width * CGFloat(state.scale)
        let height = placed.height * CGFloat(state.scale)
        return CGRect(
            x: CGFloat(state.center.clamped.x) * size.width - width / 2,
            y: CGFloat(state.center.clamped.y) * size.height - height / 2,
            width: width, height: height
        )
    }
}
