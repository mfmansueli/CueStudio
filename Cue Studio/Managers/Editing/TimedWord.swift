//
//  TimedWord.swift
//  Cue Studio
//

import Foundation

/// A word heard in the take, with when it was said.
nonisolated struct TimedWord: Hashable, Sendable {
    var text: String
    var start: TimeInterval
    var end: TimeInterval
}
