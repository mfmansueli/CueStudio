//
//  VideoExporting+NoProgress.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
extension VideoExporting {
    /// An export whose progress nobody follows: what the export tests ask for (its file).
    func export(videoAt url: URL, options: ExportOptions) async throws -> URL {
        try await export(videoAt: url, options: options, progress: nil).url
    }
}
