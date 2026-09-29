//
//  EditMediaFiles.swift
//  Cue Studio
//

import Foundation

/// The app's copies of what Quick edit adds to a take: photos and videos from the library
/// (B-roll, a cover photo) and recorded voice-overs, in Application Support/EditMedia. Edits name
/// them by file name, never by URL, because the container's path changes between installs.
/// Everything stays on the device.
nonisolated enum EditMediaFiles {
    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "EditMedia", directoryHint: .isDirectory)
    }

    static func url(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    static func exists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName).path(percentEncoded: false))
    }

    /// A new, unused file name with `pathExtension`, and where it goes (the folder exists).
    static func newFile(pathExtension: String) throws -> (name: String, url: URL) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = pathExtension.isEmpty ? "dat" : pathExtension.lowercased()
        let name = UUID().uuidString + "." + ext
        return (name, url(for: name))
    }

    /// Removes files nothing names any more (a deleted take's media, what an edit left behind).
    /// Never touches a take's recording, which lives elsewhere.
    static func remove(_ names: Set<String>) {
        for name in names where !name.isEmpty && !name.contains("/") {
            try? FileManager.default.removeItem(at: url(for: name))
        }
    }
}
