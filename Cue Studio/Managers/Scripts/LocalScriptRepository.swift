//
//  LocalScriptRepository.swift
//  Cue Studio
//

import Foundation

/// Stores the script library as JSON in Application Support. Scripts are small text, so one file
/// written atomically is simpler and safer than a database.
struct LocalScriptRepository: ScriptRepository {
    private let fileURL: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Library", directoryHint: .isDirectory)) {
        fileURL = directory.appending(path: "scripts.json")
    }

    func load() throws -> ScriptLibrarySnapshot {
        // Unencoded: `path()` gives "Application%20Support", which FileManager never finds.
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return ScriptLibrarySnapshot() }
        let data = try Data(contentsOf: fileURL)
        let snapshot = try JSONDecoder.library.decode(ScriptLibrarySnapshot.self, from: data)
        // A script that couldn't be read is left out; the next save writes the library without it, so the file as it was is
        // kept aside first.
        let saved = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["scripts"] as? [Any]
        if let saved, saved.count > snapshot.scripts.count { keepCopy(of: data) }
        return snapshot
    }

    /// `scripts.json` as it was, next to it (`scripts-kept-<date>.json`).
    private func keepCopy(of data: Data) {
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let copy = fileURL.deletingLastPathComponent().appending(path: "scripts-kept-\(stamp).json")
        try? data.write(to: copy, options: [.atomic, .completeFileProtection])
    }

    func save(_ snapshot: ScriptLibrarySnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder.library.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
