//
//  GuidancePlace.swift
//  Cue Studio
//

import Foundation

/// A screen where Cue may suggest something on its own (`GuidanceGate`): one suggestion at a time in each.
nonisolated enum GuidancePlace: String, CaseIterable, Sendable {
    /// Scripts, above the dock (and the dock's own line).
    case scripts
    /// Takes, above the tab bar.
    case takes
}
