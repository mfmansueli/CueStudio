//
//  MediaPick.swift
//  Cue Studio
//

import Foundation

/// A photo or video picked to go in, already copied into the edit's media (`EditMediaFiles`), with the part of a video
/// chosen before it goes in (`MediaPartStrip`).
nonisolated struct MediaPick: Identifiable, Hashable, Sendable {
    let id: UUID
    let imported: ImportedMedia
    /// Seconds of the video where the part starts.
    var start: TimeInterval = 0
    /// How long the part is; nil: from `start` to the video's end (a photo shows `MediaOverlay.photoDuration`).
    var length: TimeInterval?

    init(_ imported: ImportedMedia, id: UUID = UUID()) {
        self.id = id
        self.imported = imported
    }

    var isVideo: Bool { imported.kind == .video }

    /// The video's length; nil for a photo.
    var fileLength: TimeInterval? { imported.duration }

    /// How long it shows when it goes in whole: its part, the rest of the video, or a photo's seconds.
    var wanted: TimeInterval {
        guard let fileLength else { return length ?? MediaOverlay.photoDuration }
        return min(length ?? .greatestFiniteMagnitude, max(0, fileLength - start))
    }
}
