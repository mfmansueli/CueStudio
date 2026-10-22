//
//  UITestLeftovers.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// What UI tests' exports leave in the temporary folder, which outlives launches: about 70 MB a video, and nothing else ever
/// removes them in memory mode (`EditStorageCleaner` runs only on real launches). Never shipped.
enum UITestLeftovers {
    /// Exports (`Cue-<id>.mov`, `VideoExportService`) older than an hour: from earlier runs, never from this test's launches.
    static func removeOldExports(olderThan age: TimeInterval = 3600, now: Date = .now) {
        let folder = URL.temporaryDirectory
        for (name, modified) in EditStorageCleaner.modified(in: folder)
        where name.hasPrefix("Cue-") && name.hasSuffix(".mov") && now.timeIntervalSince(modified) > age {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }
}
#endif
