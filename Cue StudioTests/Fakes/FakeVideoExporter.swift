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

    func export(videoAt url: URL, options: ExportOptions) async throws -> URL {
        if let error { throw error }
        exports.append(options)
        return URL.temporaryDirectory.appending(path: "export-\(exports.count).mov")
    }
}
