//
//  MediaLibraryFiles.swift
//  Cue Studio
//

import CryptoKit
import Foundation

/// The creator's library files, in Application Support/MediaLibrary (with `library.json`, the list), on this iPhone only.
/// A file comes in as a hard link to a file Cue already has (an import, a video's media): the same bytes, no space used; it
/// goes into a video the same way (`EditMediaFiles.link`), so the library and each video own their own name for it, and
/// the bytes stay while any of them does.
nonisolated enum MediaLibraryFiles {
    static var directory: URL {
        URL.applicationSupportDirectory.appending(path: "MediaLibrary", directoryHint: .isDirectory)
    }

    static func url(for fileName: String, in folder: URL = directory) -> URL {
        folder.appending(path: fileName)
    }

    static func exists(_ fileName: String, in folder: URL = directory) -> Bool {
        FileManager.default.fileExists(atPath: url(for: fileName, in: folder).path(percentEncoded: false))
    }

    /// `source` kept in the library under a new name: a hard link, or a copy where one can't be made.
    static func keep(_ source: URL, in folder: URL = directory) throws -> String {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = source.pathExtension.isEmpty ? "dat" : source.pathExtension.lowercased()
        let name = UUID().uuidString + "." + ext
        let destination = url(for: name, in: folder)
        do {
            try FileManager.default.linkItem(at: source, to: destination)
        } catch {
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return name
    }

    /// How many names the file's bytes have (the library's, and each video's that uses it).
    static func linkCount(of fileName: String, in folder: URL = directory) -> Int {
        let path = url(for: fileName, in: folder).path(percentEncoded: false)
        return ((try? FileManager.default.attributesOfItem(atPath: path))?[.referenceCount] as? Int) ?? 1
    }

    /// SHA-256 of the file, read a few megabytes at a time.
    static func fingerprint(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
            hash.update(data: chunk)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// "Delete my Cue data": the folder whole.
    static func removeAll(in folder: URL = directory) {
        try? FileManager.default.removeItem(at: folder)
    }
}
