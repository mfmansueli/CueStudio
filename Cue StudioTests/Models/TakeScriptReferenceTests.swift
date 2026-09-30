//
//  TakeScriptReferenceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("Recorded script reference")
struct TakeScriptReferenceTests {
    @Test func laterScriptChangesNeverReplaceTheRecordedReference() throws {
        let original = TestData.script(text: "Sua ideia merece ganhar vida.", language: .portugueseBrazil)
        var take = TestData.take(scriptID: original.id)
        take.scriptReference = original
        var changed = original
        changed.text = "A completely different script."
        changed.version += 1
        changed.language = .english
        let decoded = try JSONDecoder().decode(Take.self, from: JSONEncoder().encode(take))
        #expect(decoded.captionScript(current: changed) == original)
        #expect(decoded.captionScript(current: nil) == original)
    }

    @Test func anOldTakeOnlyUsesACurrentScriptWithTheRecordedVersion() {
        var script = TestData.script()
        let take = TestData.take(scriptID: script.id)
        #expect(take.captionScript(current: script) == script)
        script.version += 1
        #expect(take.captionScript(current: script) == nil)
    }
}
