//
//  MotionAnalysisStore.swift
//  Cue Studio
//

import Foundation

/// Where a recording's motion analysis is kept: in a file next to it (`<recording>.cuemotion`), so it goes wherever the
/// recording's name goes and is removed with it. It's a cache: nothing is lost when it's missing (it's made again), and it's
/// left out of backups.
nonisolated enum MotionAnalysisStore {
    static let pathExtension = "cuemotion"

    /// The analysis file of the recording at `recording`.
    static func url(forRecording recording: URL) -> URL {
        recording.appendingPathExtension(pathExtension)
    }

    /// The analysis kept for the recording, of any version; nil when there's none or it can't be read.
    static func load(forRecording recording: URL) -> MotionAnalysis? {
        guard let data = try? Data(contentsOf: url(forRecording: recording)) else { return nil }
        return try? JSONDecoder().decode(MotionAnalysis.self, from: data)
    }

    /// The analysis of the recording when it's complete and of this version.
    static func complete(forRecording recording: URL) -> MotionAnalysis? {
        guard let analysis = load(forRecording: recording), analysis.isCurrent, analysis.isComplete else { return nil }
        return analysis
    }

    static func save(_ analysis: MotionAnalysis, forRecording recording: URL) {
        var file = url(forRecording: recording)
        guard let data = try? JSONEncoder().encode(analysis) else { return }
        do {
            try data.write(to: file, options: .atomic)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? file.setResourceValues(values)
        } catch {
            // A cache that can't be written is made again next time.
        }
    }

    static func remove(forRecording recording: URL) {
        try? FileManager.default.removeItem(at: url(forRecording: recording))
    }
}
