//
//  NoStyleReader.swift
//  Cue Studio
//

import Foundation

/// The reader of a device with no model, and of tests that want the import without one.
@MainActor
final class NoStyleReader: WritingStyleReading {
    func canRead(language: String?) -> Bool { false }
    func read(_ samples: [String], language: String?) async -> StyleReading? { nil }
}
