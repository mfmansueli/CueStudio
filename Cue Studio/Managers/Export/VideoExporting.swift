//
//  VideoExporting.swift
//  Cue Studio
//

import Foundation

protocol VideoExporting: AnyObject {
    /// Writes a copy of the video ready to post and returns its temporary URL. `progress` hears
    /// how far it is, 0 to 1, on the main actor.
    func export(videoAt url: URL, options: ExportOptions, progress: (@MainActor (Double) -> Void)?) async throws -> URL
}
