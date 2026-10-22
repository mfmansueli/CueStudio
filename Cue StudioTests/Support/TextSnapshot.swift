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
/// The kept texts are read from the test bundle, where the build copies them: the source tree may sit in a folder macOS guards
/// (Desktop, Documents), which the simulator is refused now and then. Recording writes them into the source tree (`#filePath`), or
/// into the folder the variable names.
enum TextSnapshot {
    private final class BundleToken {}

    private static let records = ProcessInfo.processInfo.environment["CUE_RECORD_SNAPSHOTS"] != nil
    /// `TEST_RUNNER_CUE_RECORD_SNAPSHOTS=<folder>` records there instead of the source tree (when macOS won't let the simulator
    /// write into it); copy the files into `Fixtures/<folder>` after.
    private static let recordFolder = ProcessInfo.processInfo.environment["CUE_RECORD_SNAPSHOTS"].flatMap { value in
        value.hasPrefix("/") ? URL(fileURLWithPath: value, isDirectory: true) : nil
    }

    /// `Cue StudioTests/Fixtures`.
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures")

    static func url(_ name: String, in folder: String) -> URL {
        root.appendingPathComponent(folder).appendingPathComponent("\(folder.replacingOccurrences(of: "/", with: "-"))-\(name).txt")
    }

    /// The kept text as built into the test bundle.
    private static func kept(_ name: String, in folder: String) throws -> String {
        let file = url(name, in: folder).deletingPathExtension().lastPathComponent
        guard let bundled = Bundle(for: BundleToken.self).url(forResource: file, withExtension: "txt") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: bundled, encoding: .utf8)
    }

    static func write(_ text: String, named name: String, in folder: String) throws {
        let source = url(name, in: folder)
        let url = recordFolder.map { $0.appendingPathComponent(source.lastPathComponent) } ?? source
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
        let kept: String
        do {
            kept = try Self.kept(name, in: folder)
        } catch {
            Issue.record(
                "No snapshot \(url(name, in: folder).lastPathComponent) (\(error)): run once with TEST_RUNNER_CUE_RECORD_SNAPSHOTS=1",
                sourceLocation: sourceLocation
            )
            return
        }
        #expect(kept == text + "\n", "\(url(name, in: folder).lastPathComponent) differs from what the app builds now", sourceLocation: sourceLocation)
    }
}
