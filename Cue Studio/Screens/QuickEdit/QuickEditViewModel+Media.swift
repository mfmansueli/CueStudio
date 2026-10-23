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
            toast.show(String(localized: "No room · Move the playhead"))
            return
        }
        guard LayerLanes.peak(of: mediaBars.map(\.span), within: placed) < MediaOverlay.simultaneousLimit else {
            EditMediaFiles.remove([imported.fileName])
            importedFiles.remove(imported.fileName)
            toast.show(String(localized: "Max 3 photos or videos"))
            return
        }
        let pinned = edit.pin(placed)
        var media = MediaOverlay(
            kind: imported.kind, fileName: imported.fileName, aspect: imported.aspect,
            mediaDuration: imported.duration, span: pinned.span
        )
        media.clipAnchor = pinned.anchor
        media.hasSound = imported.kind == .video ? imported.hasSound : nil
        media.layer = (edit.media.map(\.stackOrder).max() ?? -1) + 1
        change { $0.media.append(media) }
        selectedMediaID = media.id
        // Muted until the creator says to keep its sound.
        if imported.kind == .video, imported.hasSound { soundChoiceMediaID = media.id }
        player.pause()
        player.seek(to: start)
        let place = DurationText.editor(start)
        sayUndoable(imported.kind == .photo ? String(localized: "Photo added at \(place)") : String(localized: "Video added at \(place)"))
    }

    /// Answers "keep its sound?" for a video just added: kept at full volume, or muted.
    func chooseSound(for id: UUID, keeps: Bool) {
        if soundChoiceMediaID == id { soundChoiceMediaID = nil }
        if keeps { setMediaSoundVolume(id, 1) }
    }

    /// A video's own sound: 0 mutes it.
    func setMediaSoundVolume(_ id: UUID, _ volume: Double) {
        let clamped = min(max(volume, 0), 1)
        updateMedia(id) { $0.audioVolume = clamped > 0.001 ? clamped : nil }
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

    /// A copy of the photo or video on top of the others, a little lower when it doesn't fill the frame, picked. The file is
    /// shared (it goes only when nothing names it).
    func duplicateMedia(_ id: UUID) {
        guard let original = edit.media.first(where: { $0.id == id }) else { return }
        // The copy shows over the same moment: never more than the export draws at once.
        let shown = mediaBars.first { $0.id == id }?.span ?? original.span
        guard LayerLanes.peak(of: mediaBars.map(\.span), within: shown) < MediaOverlay.simultaneousLimit else {
            toast.show(String(localized: "Max 3 photos or videos"))
            return
        }
        var copy = original
        copy.id = UUID()
        copy.layer = (edit.media.map(\.stackOrder).max() ?? 0) + 1
        if copy.layout != .fullFrame {
            copy.center = OverlayPoint(x: original.center.x, y: min(0.9, original.center.y + 0.08)).clamped
        }
        change { $0.media.append(copy) }
        selection = .media(copy.id)
        sayUndoable(String(localized: "Media duplicated"))
    }

    func deleteMedia(_ id: UUID) {
        change { $0.media.removeAll { $0.id == id } }
        toast.show(String(localized: "Media removed"))
    }

    // MARK: - The part of a video

    /// Plays another part of the video (`start`, seconds of the file) in the same place of the edit, for as long as it shows
    /// there; kept inside the file. A drag is one undo step (`beginChange`).
    func slipMedia(_ id: UUID, toStart start: TimeInterval) {
        guard let media = edit.media.first(where: { $0.id == id }), let length = media.mediaDuration,
              let shown = mediaBars.first(where: { $0.id == id })?.span.duration else { return }
        let clamped = min(max(0, start), max(0, length - shown))
        updateMedia(id) { $0.mediaStart = clamped > 0.000_1 ? clamped : nil }
    }

    /// How long the photo or video shows, from where it starts in the edit: longer is as far as the video (from its part) and the
    /// edit allow. One undo step per tap.
    func setMediaLength(_ id: UUID, _ seconds: TimeInterval) {
        guard let media = edit.media.first(where: { $0.id == id }), let bar = mediaBars.first(where: { $0.id == id }) else { return }
        let longest = min(media.longestDuration, edit.editedDuration - bar.span.start)
        let length = min(max(seconds, MediaOverlay.minimumDuration), longest)
        guard abs(length - bar.span.duration) > 0.01 else { return }
        let pinned = edit.pin(TimeSpan(start: bar.span.start, end: bar.span.start + length))
        updateMedia(id) { item in
            item.span = pinned.span
            item.clipAnchor = pinned.anchor
        }
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
