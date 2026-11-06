//
//  SlowVideoExporter.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// An export that takes its time (`-uiTestSlowExport`): a second of preparing, then the frames' progress climbing over a few
/// seconds before the real export, so UI tests can see the review while it runs. Never shipped.
@MainActor
final class SlowVideoExporter: VideoExporting {
    private let inner: VideoExporting
    private let steps = 40

    init(inner: VideoExporting) {
        self.inner = inner
    }

    func export(videoAt url: URL, options: ExportOptions, progress: (@MainActor (ExportProgress) -> Void)?) async throws -> ExportResult {
        let preparing = 7
        for step in 0..<steps {
            let rendered = Double(step - preparing) / Double(steps - preparing) * 0.9
            progress?(step < preparing ? .preparing : ExportProgress(.rendering, fraction: rendered))
            try await Task.sleep(for: .milliseconds(150))
        }
        return try await inner.export(videoAt: url, options: options) { update in
            progress?(ExportProgress(.rendering, fraction: 0.9 + (update.stage == .rendering ? update.fraction ?? 0 : 0) * 0.1))
        }
    }
}
#endif
