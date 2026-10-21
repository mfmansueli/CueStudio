//
//  MotionClockReference.swift
//  Cue Studio
//

import Foundation

/// A `MotionClock` held by reference, for a timeline's frames to read as it is now. Held by value in `@State`, a `TimelineView`'s content
/// could keep drawing with the copy it was made with, from before the clock started, and stand at zero for good (the Profile's mini universe,
/// 21/10/2026: it only moved once its screen had been left and opened again).
final class MotionClockReference {
    var clock = MotionClock()
}
