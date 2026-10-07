//
//  FakeStyleReader.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// A style reader that answers what the test says, and remembers what it was asked.
@MainActor
final class FakeStyleReader: WritingStyleReading {
    var available = true
    var answer: StyleReading?
    /// Held until the test lets it go, so a test can cancel while the model is "thinking".
    var stalls = false
    private(set) var reads = 0
    private(set) var lastSamples: [String] = []

    init(answer: StyleReading? = StyleReading(tones: ["casual"], topics: ["fitness"], audience: "youngAdults", humor: "little")) {
        self.answer = answer
    }

    func canRead(language: String?) -> Bool { available }

    func read(_ samples: [String], language: String?) async -> StyleReading? {
        reads += 1
        lastSamples = samples
        if stalls { try? await Task.sleep(for: .seconds(60)) }
        return Task.isCancelled ? nil : answer
    }
}
