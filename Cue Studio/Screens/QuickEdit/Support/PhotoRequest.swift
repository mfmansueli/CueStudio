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
        /// Another file for a photo or video already on the media track (`kind` is what it is now).
        case replaceMedia(UUID, kind: MediaKind)
        /// Another video for a clip of the timeline (Replace clip).
        case replaceClip(UUID)
    }

    /// Every request is its own, so asking again for the same thing after a cancel shows the picker again.
    let id = UUID()
    let purpose: Purpose

    /// Replacing a clip offers videos; replacing a photo or video, either (one can take the other's place); the background,
    /// photos.
    var filter: PHPickerFilter {
        switch purpose {
        case .replaceMedia: .any(of: [.images, .videos])
        case .replaceClip: .videos
        case .background: .images
        }
    }
}
