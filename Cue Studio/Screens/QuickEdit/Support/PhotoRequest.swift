//
//  PhotoRequest.swift
//  Cue Studio
//

import Foundation
import PhotosUI

/// Why the editor opens the photo library: one request at a time, and one place that shows the
/// picker for all of them (`EditorPhotoPicker`), whichever panel or toolbar button asked.
nonisolated struct PhotoRequest: Equatable, Sendable {
    enum Purpose: Equatable, Sendable {
        /// The photo behind the creator (Background › Image).
        case background
        /// The cover's photo.
        case cover
        /// Another file for a photo or video already on the media track (`kind` is what it is now).
        case replaceMedia(UUID, kind: MediaKind)
    }

    /// Every request is its own, so asking again for the same thing after a cancel shows the picker again.
    let id = UUID()
    let purpose: Purpose

    /// Replacing a video offers videos; everything else offers photos.
    var offersVideos: Bool {
        if case .replaceMedia(_, .video) = purpose { return true }
        return false
    }

    var filter: PHPickerFilter { offersVideos ? .videos : .images }
}
