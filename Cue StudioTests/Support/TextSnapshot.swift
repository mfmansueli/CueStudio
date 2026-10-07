//
//  TextSnapshot.swift
//  Cue StudioTests
//

import Foundation
import Testing

/// A text kept in `Cue StudioTests/Fixtures/<folder>/<folder>-<name>.txt` (slashes of the folder become dashes: the files of a test bundle share one flat
/// folder, so two sets can't both hold a `yoga-teacher.txt`) that a test compares what the app produces with, so a change to what
/// the model is sent shows up as a diff in review. Run with `TEST_RUNNER_CUE_RECORD_SNAPSHOTS=1` (simulator) to write the files again.
///
/// The files are read from the source tree through `#filePath`, not from the test bundle: they are for the simulator, which sees the Mac's disk.
enum TextSnapshot {
    private static let records = ProcessInfo.processInfo.environment["CUE_RECORD_SNAPSHOTS"] != nil

    /// `Cue StudioTests/Fixtures`.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")

    static func url(_ name: String, in folder: String) -> URL {
        root.appendingPathComponent(folder).appendingPathComponent("\(folder.replacingOccurrences(of: "/", with: "-"))-\(name).txt")
    }

    /// The kept text (nil when there is none yet).
    static func stored(_ name: String, in folder: String) -> String? {
        try? String(contentsOf: url(name, in: folder), encoding: .utf8)
    }

    static func write(_ text: String, named name: String, in folder: String) throws {
        let url = url(name, in: folder)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try (text + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// Passes when `text` is what was kept. Records instead when asked to.
    static func expect(
        _ text: String, named name: String, in folder: String, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        if records {
            try write(text, named: name, in: folder)
            return
        }
        guard let kept = stored(name, in: folder) else {
            Issue.record("No snapshot \(url(name, in: folder).lastPathComponent): run once with TEST_RUNNER_CUE_RECORD_SNAPSHOTS=1", sourceLocation: sourceLocation)
            return
        }
        #expect(kept == text + "\n", "\(url(name, in: folder).lastPathComponent) differs from what the app builds now", sourceLocation: sourceLocation)
    }
}
