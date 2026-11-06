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
    /// Runs halfway through, like iOS ending the task mid-export; a cancelled export throws, as `AVAssetExportSession` does.
    var beforeFinishing: (@MainActor () -> Void)?
    /// A step that doesn't hear a cancel (a font download, the composition being built): the file is made anyway.
    var ignoresCancellation = false
    /// What the next exports say they drew in the system's face.
    var unavailableFonts: Set<FontPackNeed> = []
    var missingCustomFamilies: Set<String> = []

    /// Writes a real (tiny) file, like the real exporter: a file that is reused has to exist.
    func export(videoAt url: URL, options: ExportOptions, progress: (@MainActor (ExportProgress) -> Void)?) async throws -> ExportResult {
        if let error { throw error }
        progress?(.preparing)
        progress?(ExportProgress(.rendering, fraction: 0.5))
        beforeFinishing?()
        if !ignoresCancellation { try Task.checkCancellation() }
        progress?(ExportProgress(.rendering, fraction: 1))
        exports.append(options)
        let file = URL.temporaryDirectory.appending(path: "Cue-test-\(UUID().uuidString.prefix(8)).mov")
        try Data([0]).write(to: file)
        files.append(file)
        return ExportResult(url: file, unavailableFonts: unavailableFonts, missingCustomFamilies: missingCustomFamilies)
    }
}
