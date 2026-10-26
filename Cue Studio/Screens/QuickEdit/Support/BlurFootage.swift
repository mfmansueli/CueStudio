//
//  BlurFootage.swift
//  Cue Studio
//

import Foundation

/// The footage under the playhead that a new Blur area goes on: which (`BlurTarget`), the second of it showing, its file, and
/// the stretch a new area covers (the clip of it under the playhead, or the photo or video over the take whole).
struct BlurFootage: Equatable {
    var target: BlurTarget
    /// Seconds of the footage at the playhead.
    var time: TimeInterval
    var url: URL
    var isVideo: Bool
    /// What a new area on it covers, in seconds of the footage.
    var span: TimeSpan
}
