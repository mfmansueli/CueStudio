//
//  UITestLeftovers.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// What UI tests leave on the iPhone, in folders that outlive launches: exports of about 70 MB a video, the sample takes' videos
/// (about 260 MB, written once and reused by every in-memory launch) and the demo edit's media. Nothing else removes them in memory
/// mode, and a real launch never uses them. Never shipped.
nonisolated enum UITestLeftovers {
    /// Names only UI tests give files: the sample takes (`SampleTakes`, `-uiTestDemoEdit`, `-uiTestLongTake`) and their edit's media
    /// (`SampleEditMedia`), the demo camera's takes, the seeded library's images, and each launch's asset folder.
    static let testPrefixes = ["sample-", "demo-take-", "seed-", "UITestAssets-"]

    static func isTestFile(_ name: String) -> Bool {
        testPrefixes.contains { name.hasPrefix($0) }
    }

    /// On a real launch (`CueStudioApp`, never in memory): every file a UI test left, in the temporary folder and among the edits'
    /// media, whatever its age. The next test run writes the samples again.
    @concurrent
    static func removeAll(temporary: URL = .temporaryDirectory, media: URL = EditMediaFiles.directory) async {
        for folder in [temporary, media] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
            for name in names where isTestFile(name) {
                try? FileManager.default.removeItem(at: folder.appending(path: name))
            }
        }
    }

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
