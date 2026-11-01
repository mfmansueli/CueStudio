//
//  RecordedClip.swift
//  Cue Studio
//

import Foundation

/// A finished recording still in the temporary folder.
nonisolated struct RecordedClip: Hashable, Sendable {
    var url: URL
    var duration: TimeInterval
    /// What the camera really recorded, which can be less than asked for (the front camera has no 4K at 60 fps on every iPhone, and the
    /// format falls back to the largest it has): what the take says and offers to export. Nil when unknown (the asked one stands).
    var resolution: VideoResolution?
    var frameRate: FrameRate?
}
