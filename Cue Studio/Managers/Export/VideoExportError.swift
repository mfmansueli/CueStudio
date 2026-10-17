//
//  VideoExportError.swift
//  Cue Studio
//

import Foundation

nonisolated enum VideoExportError: LocalizedError, Sendable {
    case noVideoTrack
    case exportUnavailable
    /// iOS stopped the export while Cue was in the background (`AVError.operationInterrupted`).
    case interrupted
    /// The iPhone got too hot to finish the motion analysis Follow face or Stabilize needs (`EditedComposition.BuildError.tooWarm`).
    case tooWarm

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: String(localized: "This take has no video.")
        case .exportUnavailable: String(localized: "This take can't be exported on this device.")
        case .interrupted: String(localized: "The export stopped while Cue was in the background.")
        case .tooWarm: String(localized: "Your iPhone is too warm to finish this video. Let it cool down, then export again.")
        }
    }
}
