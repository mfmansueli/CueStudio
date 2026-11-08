//
//  PersonMaskMoment.swift
//  Cue Studio
//

import Foundation

/// Which frame a person mask is asked for (`PersonMasker.mask(for:at:)`): `key` names the frame (for the cache), `track` the stream of
/// frames it belongs to (a background of one build, on the main side or the other side of a dissolve), `epoch` the stretch of video
/// that is playing and `time` its moment, in the edit's seconds.
nonisolated struct PersonMaskMoment: Hashable, Sendable {
    let key: String
    let track: String
    let epoch: Double
    let time: TimeInterval
}
