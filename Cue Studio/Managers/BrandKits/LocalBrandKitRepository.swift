//
//  LocalBrandKitRepository.swift
//  Cue Studio
//

import Foundation

/// The kits as JSON next to their logos (`BrandKitFiles`), readable once the iPhone was unlocked after it started.
nonisolated struct LocalBrandKitRepository: BrandKitRepository {
    private let fileURL: URL

    init(directory: URL = BrandKitFiles.directory) {
        fileURL = directory.appending(path: "kits.json")
    }

    func load() throws -> [BrandKit] {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else { return [] }
        // Kit by kit: one that can't be read stays out, never the whole list.
        return try JSONDecoder().decode(LossyList<BrandKit>.self, from: Data(contentsOf: fileURL)).elements
    }

    func save(_ kits: [BrandKit]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(kits).write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
