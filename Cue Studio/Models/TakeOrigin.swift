//
//  TakeOrigin.swift
//  Cue Studio
//

import Foundation

/// Where a take's video came from: recorded with Cue, or imported from Photos to be edited (it never shows as a recording of
/// the teleprompter: no take number, no retake, no script).
nonisolated enum TakeOrigin: String, LenientChoice, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = TakeOrigin.recorded

    case recorded
    case imported
}
