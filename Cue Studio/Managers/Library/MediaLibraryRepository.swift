//
//  MediaLibraryRepository.swift
//  Cue Studio
//

import Foundation

/// Where the library's list is kept.
protocol MediaLibraryRepository: Sendable {
    func load() throws -> [LibraryAsset]
    func save(_ assets: [LibraryAsset]) throws
}

/// The list as JSON next to the files (`MediaLibraryFiles`).
nonisolated struct LocalMediaLibraryRepository: MediaLibraryRepository {
    private let fileURL: URL

    init(directory: URL = MediaLibraryFiles.directory) {
        fileURL = directory.appending(path: "library.json")
    }

    func load() throws -> [LibraryAsset] {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return [] }
        // File by file: one that can't be read stays out, never the whole list.
        return try JSONDecoder().decode(LossyList<LibraryAsset>.self, from: Data(contentsOf: fileURL)).elements
    }

    func save(_ assets: [LibraryAsset]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(assets).write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
