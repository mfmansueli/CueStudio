//
//  CustomFontRepository.swift
//  Cue Studio
//

import Foundation

/// Where the imported families are kept.
protocol CustomFontRepository: Sendable {
    func load() throws -> [CustomFontFamily]
    func save(_ families: [CustomFontFamily]) throws
}

/// The families as JSON next to their files (`CustomFontFiles`).
nonisolated struct LocalCustomFontRepository: CustomFontRepository {
    private let fileURL: URL

    init(directory: URL = CustomFontFiles.directory) {
        fileURL = directory.appending(path: "fonts.json")
    }

    func load() throws -> [CustomFontFamily] {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return [] }
        // Family by family: one that can't be read stays out, never the whole list.
        return try JSONDecoder().decode(LossyList<CustomFontFamily>.self, from: Data(contentsOf: fileURL)).elements
    }

    func save(_ families: [CustomFontFamily]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(families).write(to: fileURL, options: [.atomic, .completeFileProtection])
    }
}
