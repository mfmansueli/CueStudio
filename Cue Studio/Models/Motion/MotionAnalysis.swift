//
//  MotionAnalysis.swift
//  Cue Studio
//

import Foundation

/// What Vision found in one recording, kept next to it (`MotionAnalysisStore`): who is in the frame over time (`subjects`) and
/// how the picture moved from frame to frame (`shifts`). Face follow and stabilization read it; nothing in an edit depends on it
/// being there, so an edit never breaks when it's missing or from another version (it's made again).
///
/// Made a piece at a time (`analyzedUntil`): the analysis stops when Cue goes to the background or the iPhone gets hot, and goes
/// on from there later.
nonisolated struct MotionAnalysis: Codable, Hashable, Sendable {
    /// Bumped when what's measured or how changes: an analysis of another version is made again.
    static let currentVersion = 1
    /// How often faces and bodies are looked for, in seconds.
    static let subjectInterval: TimeInterval = 0.1
    /// Fastest frame rate the registration measures (a 60 fps recording is read every other frame).
    static let shiftRate: Double = 30

    var version = Self.currentVersion
    /// The recording's length, in seconds.
    var duration: TimeInterval
    /// Its upright frame's size, in pixels.
    var width: Double
    var height: Double
    /// Its frames per second (each correction belongs to a frame, however long the edit holds it); nil reads 30.
    var frameRate: Double?
    /// Seconds of the recording analyzed so far, from its start.
    var analyzedUntil: TimeInterval = 0
    var subjects: [SubjectSample] = []
    var shifts: [FrameShift] = []

    init(duration: TimeInterval, width: Double, height: Double) {
        self.duration = max(0, duration)
        self.width = width
        self.height = height
    }

    /// The whole recording has been analyzed.
    var isComplete: Bool { analyzedUntil >= duration - 0.05 }

    /// How much of the recording has been analyzed, 0 to 1.
    var progress: Double { duration > 0 ? min(1, analyzedUntil / duration) : 1 }

    /// Width over height of the upright frame.
    var aspect: Double { height > 0 ? width / height : 1 }

    /// Whether this analysis can be used (and continued) by this version of Cue.
    var isCurrent: Bool { version == Self.currentVersion }
}
