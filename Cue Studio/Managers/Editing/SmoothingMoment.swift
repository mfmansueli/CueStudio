//
//  SmoothingMoment.swift
//  Cue Studio
//

import Foundation

/// Which frame of which stretch of video Skin Smoothing is being asked for: the side of a dissolve it is on, the stretch (the compositor's instruction,
/// named by where it starts) and the time. A new stretch forgets the faces of the one before; the same stretch carries them from frame to frame.
nonisolated struct SmoothingMoment {
    let stream: SkinSmoother.Stream
    let stretch: Double
    let time: TimeInterval
}
