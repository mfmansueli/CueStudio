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

    /// The words on the cover; a cover is made from the playhead's frame when there's none yet.
    /// Typing in a row is one undo step.
    func setCoverTitle(_ title: String) {
        if edit.cover == nil {
            guard isReady else { return }
            setCoverSource(.frame(edit.timeline.sourceTime(forEdited: player.currentTime)))
        }
        change(key: "coverTitle") { $0.cover?.title = title }
    }

    // MARK: - Cover panel

    /// The cover is a photo (else a frame of the video).
    var coverIsPhoto: Bool {
        if case .photo? = edit.cover?.source { return true }
        return false
    }

    /// Where the cover's frame is in the edit (edited seconds): the playhead while there's no
    /// cover.
    var coverEditedTime: TimeInterval {
        guard case .frame(let time)? = edit.cover?.source else { return player.currentTime }
        return min(max(0, edit.timeline.editedTime(following: time)), edit.editedDuration)
    }

    /// Frames along the edit for Cover's strip: the recording and second each one comes from.
    func coverStripSamples(count: Int) -> [(url: URL, time: TimeInterval)] {
        let timeline = edit.timeline
        let total = edit.editedDuration
        guard count > 0, total > 0, !timeline.segments.isEmpty else { return [] }
        let others = clipSourceURLs
        return (0..<count).map { index in
            let edited = (Double(index) + 0.5) / Double(count) * total
            let segment = timeline.segments[timeline.segmentIndex(atEdited: edited)]
            let url = segment.sourceID.flatMap { others[$0] } ?? videoURL
            return (url, timeline.sourceTime(forEdited: edited))
        }
    }

    /// The finger is on Cover's strip: the video shows the frame under it.
    func scrubCover(toEdited time: TimeInterval) {
        guard isReady else { return }
        isPickingCoverFrame = true
        player.pause()
        player.seek(to: min(max(0, time), edit.editedDuration))
    }

    /// The finger left the strip: that frame is the cover (one undo step).
    func endCoverScrub(atEdited time: TimeInterval) {
        guard isReady else { return }
        let edited = min(max(0, time), edit.editedDuration)
        setCoverSource(.frame(edit.timeline.sourceTime(forEdited: edited)))
        isPickingCoverFrame = false
    }

    /// "Frame from video": back to a frame (the playhead's) after a photo.
    func useVideoFrameForCover() {
        guard coverIsPhoto || edit.cover == nil else { return }
        useFrameAsCover()
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
                snapshot.cover = VideoCover(source: source, style: snapshot.creatorStyle ?? .bold, preset: .cue)
            }
        }
    }
}
