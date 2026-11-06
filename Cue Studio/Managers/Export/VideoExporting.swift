//
//  VideoExporting.swift
//  Cue Studio
//

import Foundation

protocol VideoExporting: AnyObject {
    /// Writes a copy of the video ready to post and returns its temporary URL. `progress` hears, on the main actor, the stage it
    /// is in and how far, when the stage can measure itself (`ExportProgress`).
    func export(videoAt url: URL, options: ExportOptions, progress: (@MainActor (ExportProgress) -> Void)?) async throws -> URL
}
