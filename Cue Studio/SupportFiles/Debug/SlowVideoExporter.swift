//
//  SlowVideoExporter.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// An export that takes its time (`-uiTestSlowExport`): the progress climbs over a few seconds before the real export,
/// so UI tests can see the review while it runs. Never shipped.
@MainActor
final class SlowVideoExporter: VideoExporting {
    private let inner: VideoExporting
    private let steps = 40

    init(inner: VideoExporting) {
        self.inner = inner
    }

    func export(videoAt url: URL, options: ExportOptions, progress: (@MainActor (Double) -> Void)?) async throws -> URL {
        for step in 0..<steps {
            progress?(Double(step) / Double(steps) * 0.9)
            try await Task.sleep(for: .milliseconds(150))
        }
        return try await inner.export(videoAt: url, options: options) { progress?(0.9 + $0 * 0.1) }
    }
}
#endif
