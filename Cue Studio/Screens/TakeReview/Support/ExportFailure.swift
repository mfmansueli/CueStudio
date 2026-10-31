//
//  ExportFailure.swift
//  Cue Studio
//

import Foundation

/// Why the last export failed, in Cue's words, and the export to try again: the review's card (`ExportFailedCard`) keeps both until the
/// creator closes it or exports again. Nothing was counted.
struct ExportFailure: Equatable {
    /// The line under "Couldn't export": what happened and, where there is one, what to do.
    let line: String
    /// What **Try again** runs: the same export (Save, a network, the queue's file).
    let action: TakeReviewViewModel.ExportAction

    init(error: any Error, action: TakeReviewViewModel.ExportAction) {
        line = Self.line(for: error)
        self.action = action
    }

    static func line(for error: any Error) -> String {
        switch error {
        case ExportPreflightError.notEnoughSpace(let megabytes):
            String(localized: "Not enough space on this iPhone. Free about \(megabytes) MB and try again.")
        case BackgroundExportError.stoppedBySystem, VideoExportError.interrupted:
            String(localized: "iOS stopped the export before it finished.")
        case VideoExportError.tooWarm:
            // Follow face or Stabilize needed an analysis the iPhone was too hot to finish; it goes on from there next time.
            VideoExportError.tooWarm.localizedDescription
        default:
            String(localized: "Nothing was counted, and your take is safe.")
        }
    }
}
