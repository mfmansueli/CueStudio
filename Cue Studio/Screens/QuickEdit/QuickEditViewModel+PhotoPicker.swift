//
//  QuickEditViewModel+PhotoPicker.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import _PhotosUI_SwiftUI

/// Asking for a photo: the panels and the toolbar only say what for (`PhotoRequest`), the editor
/// shows the picker once (`EditorPhotoPicker`), and the pick comes back here to be put where it was
/// asked for.
extension QuickEditViewModel {
    func requestPhoto(_ purpose: PhotoRequest.Purpose) {
        photoRequest = PhotoRequest(purpose: purpose)
    }

    /// The photo or video picked for the request that opened the library.
    func importPickedPhoto(_ item: PhotosPickerItem) async {
        guard let request = photoRequest else { return }
        photoRequest = nil
        switch request.purpose {
        case .background: await importBackgroundImage(item)
        case .cover: await useCoverPhoto(item)
        case .replaceMedia(let id, _): await replaceMedia(id, importing: item)
        }
    }

    /// Copies the picked file in and swaps it for the one on the media track.
    func replaceMedia(_ id: UUID, importing item: PhotosPickerItem) async {
        guard isReady, !isImportingMedia else { return }
        isImportingMedia = true
        defer { isImportingMedia = false }
        do {
            replaceMedia(id, with: try await mediaImporter.importMedia(item))
        } catch {
            toast.show(error.localizedDescription)
        }
    }

    /// Puts `imported` in the place of a photo or video: where it shows, for how long, in which
    /// window and with which keyframes stay; only the picture (or the video) changes. A photo is
    /// replaced by a photo and a video by a video, and a video that is shorter than the stretch it
    /// fills shows for its own length.
    func replaceMedia(_ id: UUID, with imported: ImportedMedia) {
        guard !isClosed, let old = edit.media.first(where: { $0.id == id }) else {
            EditMediaFiles.remove([imported.fileName])
            return
        }
        guard imported.kind == old.kind else {
            EditMediaFiles.remove([imported.fileName])
            toast.show(String(localized: "This photo or video can't be added"))
            return
        }
        importedFiles.insert(imported.fileName)
        updateMedia(id) { media in
            media.fileName = imported.fileName
            media.aspect = imported.aspect.isFinite && imported.aspect > 0 ? imported.aspect : 1
            media.mediaDuration = imported.duration
            if media.kind == .video {
                media.hasSound = imported.hasSound
                media.audioVolume = nil
                media.span.end = min(media.span.end, media.span.start + media.longestDuration)
            }
        }
        toast.show(old.kind == .photo ? String(localized: "Photo replaced") : String(localized: "Video replaced"))
    }
}
