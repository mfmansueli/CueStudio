//
//  BrandKitRepository.swift
//  Cue Studio
//

import Foundation

/// Where the brand kits are kept.
protocol BrandKitRepository: Sendable {
    func load() throws -> [BrandKit]
    func save(_ kits: [BrandKit]) throws
}
