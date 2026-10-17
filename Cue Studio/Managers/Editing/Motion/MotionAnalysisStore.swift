//
//  MotionAnalysisStore.swift
//  Cue Studio
//

import Foundation
import os

/// Where a recording's motion analysis is kept: in a file next to it (`<recording>.cuemotion`), so it goes wherever the
/// recording's name goes and is removed with it. It's a cache: nothing is lost when it's missing (it's made again), and it's
/// left out of backups.
///
/// The last few analyses read are kept in memory with their file's date, with the Stabilize paths worked out from them: the
/// panels read them on every redraw and the preview on every build, and a file is decoded again only when it changed.
nonisolated enum MotionAnalysisStore {
    static let pathExtension = "cuemotion"
    /// Analyses kept in memory.
    static let remembered = 6

    /// An analysis read from its file.
    private struct Remembered: Sendable {
        /// The file's date when it was read.
        var stamp: Date
        var analysis: MotionAnalysis?
        /// Stabilize's path at each level (nil inside: no shake to take out).
        var steady: [StabilizationLevel: StabilizationPath?] = [:]
        /// When it was last read, to forget the oldest.
        var used: UInt64
    }

    private struct Memory: Sendable {
        var files: [URL: Remembered] = [:]
        var clock: UInt64 = 0
    }

    private static let memory = OSAllocatedUnfairLock(initialState: Memory())

    /// The analysis file of the recording at `recording`.
    static func url(forRecording recording: URL) -> URL {
        recording.appendingPathExtension(pathExtension)
    }

    /// The analysis kept for the recording, of any version; nil when there's none or it can't be read.
    static func load(forRecording recording: URL) -> MotionAnalysis? {
        entry(for: url(forRecording: recording))?.analysis
    }

    /// The analysis of the recording when it's complete and of this version.
    static func complete(forRecording recording: URL) -> MotionAnalysis? {
        guard let analysis = load(forRecording: recording), analysis.isCurrent, analysis.isComplete else { return nil }
        return analysis
    }

    /// Stabilize's path for the recording at `level`, from its complete analysis, worked out once while the file doesn't
    /// change; nil without a complete analysis or when there's no shake to take out.
    static func stabilizationPath(forRecording recording: URL, level: StabilizationLevel) -> StabilizationPath? {
        let file = url(forRecording: recording)
        guard let entry = entry(for: file), let analysis = entry.analysis, analysis.isCurrent, analysis.isComplete else { return nil }
        if let known = entry.steady[level] { return known }
        let path = StabilizationPath.make(analysis, level: level)
        let key = file.standardizedFileURL
        memory.withLock { state in
            // Only onto the analysis it was worked out from.
            if state.files[key]?.stamp == entry.stamp { state.files[key]?.steady[level] = .some(path) }
        }
        return path
    }

    /// Keeps `analysis` next to the recording; nothing when the recording is gone (deleted while it was analyzed).
    static func save(_ analysis: MotionAnalysis, forRecording recording: URL) {
        guard FileManager.default.fileExists(atPath: recording.path(percentEncoded: false)) else { return }
        var file = url(forRecording: recording)
        guard let data = try? JSONEncoder().encode(analysis) else { return }
        do {
            try data.write(to: file, options: .atomic)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? file.setResourceValues(values)
            if let stamp = modificationDate(of: file) { remember(analysis, stamp: stamp, file: file) }
        } catch {
            // A cache that can't be written is made again next time.
        }
    }

    static func remove(forRecording recording: URL) {
        let file = url(forRecording: recording)
        _ = memory.withLock { $0.files.removeValue(forKey: file.standardizedFileURL) }
        try? FileManager.default.removeItem(at: file)
    }

    // MARK: - Memory

    /// The file's analysis, from memory while the file hasn't changed, else read now; nil when there's no file.
    private static func entry(for file: URL) -> Remembered? {
        let key = file.standardizedFileURL
        guard let stamp = modificationDate(of: file) else {
            _ = memory.withLock { $0.files.removeValue(forKey: key) }
            return nil
        }
        let known: Remembered? = memory.withLock { state in
            guard var entry = state.files[key], entry.stamp == stamp else { return nil }
            state.clock += 1
            entry.used = state.clock
            state.files[key] = entry
            return entry
        }
        if let known { return known }
        let analysis = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(MotionAnalysis.self, from: $0) }
        return remember(analysis, stamp: stamp, file: file)
    }

    @discardableResult
    private static func remember(_ analysis: MotionAnalysis?, stamp: Date, file: URL) -> Remembered {
        let key = file.standardizedFileURL
        return memory.withLock { state in
            state.clock += 1
            let entry = Remembered(stamp: stamp, analysis: analysis, used: state.clock)
            state.files[key] = entry
            while state.files.count > remembered, let oldest = state.files.min(by: { $0.value.used < $1.value.used })?.key {
                state.files.removeValue(forKey: oldest)
            }
            return entry
        }
    }

    private static func modificationDate(of file: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path(percentEncoded: false)))?[.modificationDate] as? Date
    }
}
