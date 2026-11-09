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
