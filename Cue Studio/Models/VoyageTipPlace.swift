//
//  VoyageTipPlace.swift
//  Cue Studio
//

import Foundation

/// Where a first voyage tip showed: above the dock on Scripts, above the tab bar on Takes, or in the place its step happens. Measured
/// per place (`VoyageTelemetryEvent`), so a line nobody acts on can be rewritten.
nonisolated enum VoyageTipPlace: String, Sendable {
    case scripts, takes
    /// The script page: Cue's first draft, and Practice over Record.
    case page
    case review, editor, share

    /// The place the step happens (not a tip floating on Scripts or Takes).
    var isInPlace: Bool { self != .scripts && self != .takes }

    /// Where the gatekeeper keeps its one suggestion (`GuidanceGate`), for the floating places.
    var guidancePlace: GuidancePlace? {
        switch self {
        case .scripts: .scripts
        case .takes: .takes
        default: nil
        }
    }
}
