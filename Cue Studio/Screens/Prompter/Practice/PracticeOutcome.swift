//
//  PracticeOutcome.swift
//  Cue Studio
//

import Foundation

/// How the first flight's practice run ends.
enum PracticeOutcome {
    /// "Record it for real": the same screen, now recording-ready.
    case recordForReal
    /// "Not now — take me to my studio".
    case studio
}
