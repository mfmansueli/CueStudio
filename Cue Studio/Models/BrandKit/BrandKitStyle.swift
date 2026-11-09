//
//  BrandKitStyle.swift
//  Cue Studio
//

import Foundation

/// A style kept in a kit, with the name it had where it came from ("Bold yellow", "This video's").
nonisolated struct BrandKitStyle<Look: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    var name: String
    var look: Look
}
