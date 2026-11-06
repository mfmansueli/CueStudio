//
//  ExportFontFallback.swift
//  Cue Studio
//

import Foundation

/// Words of an exported video drawn in the system's face because their family wasn't there: the creator is told where the video
/// is shown ("Ready to travel", the message after sending it), never left to find it in the file.
nonisolated enum ExportFontFallback: String, Codable, Equatable, Sendable {
    /// A script family (`FontPackStore`) hadn't downloaded in time (offline, a slow network): exporting again once it has fixes it.
    case notDownloaded
    /// A family the creator imported isn't on this iPhone any more.
    case notOnThisIPhone
}
