//
//  EyeContactAnalysisStore.swift
//  Cue Studio
//

import Foundation
import os

/// Where a recording's Eye Contact analysis is kept: in a file next to it (`<recording>.cueeyes`), so it goes wherever the
/// recording's name goes and is removed with it. It's a cache: nothing is lost when it's missing (it's made again), it's left out of
/// backups, and one made from another file under the same name is never used (`EyeContactAnalysis.fileStamp`).
///
/// The last few analyses read are kept in memory with their file's date and their decisions (`EyeGazePlan`): the panel reads them
/// on every redraw and the preview on every build, and a file is decoded again only when it changed.
nonisolated enum EyeContactAnalysisStore {
    static let pathExtension = "cueeyes"
    /// Analyses kept in memory (a five-minute one is about 1.3 MB).
    static let remembered = 4

    private struct Remembered: Sendable {
        /// The analysis file's date when it was read.
        var stamp: Date
        var analysis: EyeContactAnalysis?
        var plan: EyeGazePlan?
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

    /// The recording's size and modification time: another file under the same name is analyzed again. (Read with `FileManager`:
    /// `URL.resourceValues` caches what it read.)
    static func fileStamp(of recording: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: recording.path(percentEncoded: false))
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? -1
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)@\(Int(modified))"
    }

    /// The analysis kept for the recording when it's of this version and of the file there now (complete or not); nil otherwise.
    static func load(forRecording recording: URL) -> EyeContactAnalysis? {
        guard let analysis = entry(for: url(forRecording: recording))?.analysis,
              analysis.isCurrent(forFile: fileStamp(of: recording)) else { return nil }
        return analysis
    }

    /// The decisions for every analyzed frame of the recording, worked out once while its analysis doesn't change; nil without an
    /// analysis of this version and file.
    static func plan(forRecording recording: URL) -> EyeGazePlan? {
        let file = url(forRecording: recording)
        guard let entry = entry(for: file), let analysis = entry.analysis, analysis.isCurrent(forFile: fileStamp(of: recording)) else {
            return nil
        }
        if let plan = entry.plan { return plan }
        let plan = EyeGazePlan.make(analysis)
        let key = file.standardizedFileURL
        memory.withLock { state in
            // Only onto the analysis it was worked out from.
            if state.files[key]?.stamp == entry.stamp { state.files[key]?.plan = plan }
        }
        return plan
    }

    /// Keeps `analysis` next to the recording; nothing when the recording is gone (deleted while it was analyzed).
    static func save(_ analysis: EyeContactAnalysis, forRecording recording: URL) {
        guard FileManager.default.fileExists(atPath: recording.path(percentEncoded: false)) else { return }
        var file = url(forRecording: recording)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(analysis) else { return }
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
        let analysis = (try? Data(contentsOf: file)).flatMap { try? PropertyListDecoder().decode(EyeContactAnalysis.self, from: $0) }
        return remember(analysis, stamp: stamp, file: file)
    }

    @discardableResult
    private static func remember(_ analysis: EyeContactAnalysis?, stamp: Date, file: URL) -> Remembered {
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
