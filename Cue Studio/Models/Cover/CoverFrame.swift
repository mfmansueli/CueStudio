//
//  CoverFrame.swift
//  Cue Studio
//

import Foundation

/// A frame picked for the cover: which recording it is from, the clip of the edit it was picked on and the second of that
/// recording. The recording and the second say which picture it is (a clip's speed doesn't change it); the clip says which look
/// it is drawn with, since a copy of a clip can have its own Adjust, Filters or Background. When that clip leaves the edit, the
/// frame is drawn with the look of another clip still showing it, or with the recording's own once none does.
nonisolated struct CoverFrame: Codable, Hashable, Sendable {
    /// The recording (`TakeEdit.sources`); nil for the take itself.
    var sourceID: UUID?
    /// The clip (`EditSegment.id`) it was picked on; nil for covers saved before montages.
    var segmentID: UUID?
    /// Seconds of that recording.
    var time: TimeInterval
}
