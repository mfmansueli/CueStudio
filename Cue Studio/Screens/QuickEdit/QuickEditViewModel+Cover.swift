//
//  QuickEditViewModel+Cover.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// Cover: a frame of the edit (the one under the playhead) or a photo from the library, with an
/// optional title in the project's style, dragged up or down. Drawn on the device and saved to
/// Photos with each export, ready to pick as the post's cover.
extension QuickEditViewModel {
    /// The cover shows over the preview: the Cover tool is open, one was chosen and no other frame
    /// is being picked.
    var showsCoverImage: Bool {
        panel == .cover && edit.cover != nil && !isPickingCoverFrame
    }

    /// Uses the frame under the playhead.
    func useFrameAsCover() {
        guard isReady else { return }
        let time = edit.timeline.sourceTime(forEdited: player.currentTime)
        setCoverSource(.frame(time))
        isPickingCoverFrame = false
        player.pause()
        toast.show(String(localized: "Cover set to this frame"))
    }

    /// Copies the picked photo in and uses it.
    func useCoverPhoto(_ item: PhotosPickerItem) async {
        guard isReady, !isImportingMedia else { return }
        isImportingMedia = true
        defer { isImportingMedia = false }
        do {
            let imported = try await mediaImporter.importMedia(item)
            importedFiles.insert(imported.fileName)
            guard imported.kind == .photo else {
                EditMediaFiles.remove([imported.fileName])
                toast.show(String(localized: "Pick a photo for the cover"))
                return
            }
            setCoverSource(.photo(fileName: imported.fileName))
            isPickingCoverFrame = false
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    func setCoverTitle(_ title: String) {
        guard edit.cover != nil else { return }
        change { $0.cover?.title = title }
    }

    func setCoverTitlePosition(_ y: Double) {
        guard edit.cover != nil else { return }
        change { $0.cover?.titleY = min(max(y, OverlayPoint.margin), 1 - OverlayPoint.margin) }
    }

    func removeCover() {
        change { $0.cover = nil }
        coverImage = nil
    }

    /// Draws the cover for the preview, a moment after the last change.
    func drawCover() {
        coverTask?.cancel()
        guard let cover = edit.cover else {
            coverImage = nil
            isDrawingCover = false
            return
        }
        isDrawingCover = true
        let current = self.edit
        coverTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self, !Task.isCancelled else { return }
            let image = await self.editing.coverImage(cover, forVideoAt: self.videoURL, edit: current)
            guard !Task.isCancelled else { return }
            self.coverImage = image
            self.isDrawingCover = false
        }
    }

    private func setCoverSource(_ source: CoverSource) {
        change { snapshot in
            if var cover = snapshot.cover {
                cover.source = source
                snapshot.cover = cover
            } else {
                snapshot.cover = VideoCover(source: source, style: snapshot.creatorStyle ?? .bold)
            }
        }
    }
}
