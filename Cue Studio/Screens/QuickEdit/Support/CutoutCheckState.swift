//
//  CutoutCheckState.swift
//  Cue Studio
//

import Foundation

/// Where Background's Check the cutout stands: not asked (or the edit changed since), reading the video, done (the moments where the
/// cutout fails, in edited seconds, for the edit it read), or it couldn't read the video.
enum CutoutCheckState: Equatable {
    case idle
    case checking(progress: Double)
    case checked(misses: [TimeSpan], of: Int)
    case failed
}
