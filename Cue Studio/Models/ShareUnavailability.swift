//
//  ShareUnavailability.swift
//  Cue Studio
//

import Foundation

nonisolated enum ShareUnavailability: Equatable, Sendable {
    case appNotInstalled
    /// The app is there but wouldn't open.
    case couldNotOpen
}
