//
//  BackgroundExportError.swift
//  Cue Studio
//

import Foundation

nonisolated enum BackgroundExportError: Error, Equatable {
    /// iOS ended the export it was running for Cue in the background (it needed the iPhone for something else, or the
    /// creator stopped it in the Live Activity). The partial file is gone; exporting again starts over.
    case stoppedBySystem
}
