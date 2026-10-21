//
//  TrimHandle.swift
//  Cue Studio
//

import Foundation

/// The two yellow handles of the timeline: where the edit starts and where it ends.
nonisolated enum TrimHandle: Equatable, Sendable {
    case start, end
}
