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

    /// Brings a file into the edit's media: a recording for a montage, a library track or a sound effect. A hard link to the same
    /// file (no space used, and it stays if the take is deleted from the library), or a copy where a link can't be made: across
    /// volumes, or from the app's bundle where the system doesn't allow one into the data container. `linking` is the link,
    /// replaceable so the tests can refuse it. Returns the new name.
    static func link(
        _ source: URL, linking: (URL, URL) throws -> Void = { try FileManager.default.linkItem(at: $0, to: $1) }
    ) throws -> String {
        let (name, destination) = try newFile(pathExtension: source.pathExtension)
        do {
            try linking(source, destination)
        } catch {
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return name
    }

    /// "Delete my Cue data": the whole folder, with what an earlier deletion or a failed import left.
    static func removeAll(in folder: URL = directory) {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Removes files nothing names any more (a deleted take's media, what an edit left behind).
    /// Never touches a take's recording, which lives elsewhere.
    static func remove(_ names: Set<String>) {
        for name in names where !name.isEmpty && !name.contains("/") {
            try? FileManager.default.removeItem(at: url(for: name))
            // A recording's motion analysis and a sound's beats go with it.
            MotionAnalysisStore.remove(forRecording: url(for: name))
            try? FileManager.default.removeItem(at: url(for: name).appendingPathExtension(BeatStore.pathExtension))
        }
    }
}
