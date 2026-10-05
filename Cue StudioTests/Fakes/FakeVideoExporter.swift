//
//  FakeVideoExporter.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeVideoExporter: VideoExporting {
    private(set) var exports: [ExportOptions] = []
    private(set) var files: [URL] = []
    var error: Error?

    /// Writes a real (tiny) file, like the real exporter: a file that is reused has to exist.
    func export(videoAt url: URL, options: ExportOptions, progress: (@MainActor (Double) -> Void)?) async throws -> URL {
        if let error { throw error }
        progress?(0.5)
        progress?(1)
        exports.append(options)
        let file = URL.temporaryDirectory.appending(path: "Cue-test-\(UUID().uuidString.prefix(8)).mov")
        try Data([0]).write(to: file)
        files.append(file)
        return file
    }
}
