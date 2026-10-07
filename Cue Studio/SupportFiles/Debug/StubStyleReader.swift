//
//  StubStyleReader.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// A style reader for UI tests (`-uiTestStubAI`): no model, the same answer every time.
@MainActor
final class StubStyleReader: WritingStyleReading {
    func canRead(language: String?) -> Bool { true }

    func read(_ samples: [String], language: String?) async -> StyleReading? {
        StyleReading(tones: ["casual", "energetic"], topics: ["fitness"], audience: "youngAdults", humor: "little")
    }
}
#endif
