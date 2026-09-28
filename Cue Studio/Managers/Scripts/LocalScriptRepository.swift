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
        return try JSONDecoder.library.decode(ScriptLibrarySnapshot.self, from: data)
    }

    func save(_ snapshot: ScriptLibrarySnapshot) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder.library.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
