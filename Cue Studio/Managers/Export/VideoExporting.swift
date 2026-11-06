//
//  VideoExporting.swift
//  Cue Studio
//

import Foundation

protocol VideoExporting: AnyObject {
    /// Writes a copy of the video ready to post and returns it (its temporary URL, and words drawn in the system's face because their
    /// font wasn't there). `progress` hears, on the main actor, the stage it is in and how far, when the stage can measure itself
    /// (`ExportProgress`).
    func export(videoAt url: URL, options: ExportOptions, progress: (@MainActor (ExportProgress) -> Void)?) async throws -> ExportResult
}
