//
//  MediaOverlay.swift
//  Cue Studio
//

import Foundation

/// A photo or video from the creator's library laid over the take (B-roll). The file is a copy
/// kept by the app (`EditMediaFiles`), so the edit never depends on the library. Pinned to the
/// recording like texts; one at a time, never on top of another, so there are no layers to manage.
/// A video plays from its start, without its sound, for as long as it shows.
nonisolated struct MediaOverlay: Codable, Hashable, Identifiable, Sendable {
    /// Narrowest a window can be, as a fraction of the frame's width.
    static let widthRange: ClosedRange<Double> = 0.25...1
    /// Shortest it can show.
    static let minimumDuration: TimeInterval = 0.3
    /// How long a photo shows when added.
    static let photoDuration: TimeInterval = 3

    var id = UUID()
    var kind: MediaKind
    /// The copy's name in `EditMediaFiles`.
    var fileName: String
    /// Width over height of the media, upright.
    var aspect: Double
    /// Length of a video; nil for a photo.
    var mediaDuration: TimeInterval?
    /// Seconds of the recording it is pinned to.
    var span: TimeSpan
    var layout: MediaLayout = .fullFrame
    /// The window's center (unused full screen).
    var center: OverlayPoint = .center
    /// The window's width as a fraction of the frame's.
    var width: Double = 0.6
    var shape: MediaShape = .original

    init(kind: MediaKind, fileName: String, aspect: Double, mediaDuration: TimeInterval?, span: TimeSpan) {
        self.kind = kind
        self.fileName = fileName
        self.aspect = aspect.isFinite && aspect > 0 ? aspect : 1
        self.mediaDuration = mediaDuration
        self.span = span
    }

    /// The longest it can show in the edit: a video's own length, else no limit.
    var longestDuration: TimeInterval {
        mediaDuration ?? .greatestFiniteMagnitude
    }
}
