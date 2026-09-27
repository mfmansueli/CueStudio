//
//  VideoExporting.swift
//  Cue Studio
//

import Foundation

protocol VideoExporting: AnyObject {
    /// Writes a copy of the video ready to post and returns its temporary URL.
    func export(videoAt url: URL, options: ExportOptions) async throws -> URL
}
