//
//  BlurTarget.swift
//  Cue Studio
//

import Foundation

/// The footage a Blur area is on: one of the main video's recordings (the take, or another recording of a montage), wherever
/// its seconds play, or a photo or video laid over the take. Its seconds and its boxes are that footage's own, so cutting,
/// speeding up, reframing or stabilizing the edit never moves it off what it covers.
nonisolated struct BlurTarget: Codable, Hashable, Sendable {
    /// The main video's recording (nil: the take), when it isn't on a photo or video over the take.
    var recordingID: UUID?
    /// The photo or video over the take it's on (`MediaOverlay.id`); nil on the main video.
    var mediaID: UUID?

    static func recording(_ id: UUID?) -> BlurTarget { BlurTarget(recordingID: id, mediaID: nil) }
    static func media(_ id: UUID) -> BlurTarget { BlurTarget(recordingID: nil, mediaID: id) }

    var isMedia: Bool { mediaID != nil }
}
