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
}
