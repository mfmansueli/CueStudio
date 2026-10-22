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
