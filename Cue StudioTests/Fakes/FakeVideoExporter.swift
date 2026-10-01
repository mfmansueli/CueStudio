//
//  FakeVideoExporter.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeVideoExporter: VideoExporting {
    private(set) var exports: [ExportOptions] = []
    var error: Error?

    func export(videoAt url: URL, options: ExportOptions, progress: (@MainActor (Double) -> Void)?) async throws -> URL {
        if let error { throw error }
        progress?(0.5)
        progress?(1)
        exports.append(options)
        return URL.temporaryDirectory.appending(path: "export-\(exports.count).mov")
    }
}
