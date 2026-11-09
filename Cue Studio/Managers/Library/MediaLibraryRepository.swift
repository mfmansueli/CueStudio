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
