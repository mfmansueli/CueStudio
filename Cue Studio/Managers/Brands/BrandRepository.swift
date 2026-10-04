//
//  BrandRepository.swift
//  Cue Studio
//

import Foundation

/// Where saved brands are stored. Swappable so tests and previews never touch the disk.
protocol BrandRepository {
    func load() throws -> [BrandBrief]
    func save(_ brands: [BrandBrief]) throws
}

/// The brands as JSON in Application Support, next to the script library.
struct LocalBrandRepository: BrandRepository {
    private let fileURL: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Library", directoryHint: .isDirectory)) {
        fileURL = directory.appending(path: "brands.json")
    }

    func load() throws -> [BrandBrief] {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return [] }
        return try JSONDecoder().decode([BrandBrief].self, from: Data(contentsOf: fileURL))
    }

    func save(_ brands: [BrandBrief]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(brands).write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
