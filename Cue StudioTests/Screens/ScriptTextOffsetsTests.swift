//
//  ScriptTextOffsetsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ScriptTextOffsets")
struct ScriptTextOffsetsTests {
    /// "😀" is one character and two UTF-16 units: the caret after "[pause]" is 9 characters in, 10 units.
    @Test func charactersAndUnitsGoBothWaysPastAnEmoji() {
        let text = "😀 [pause] go"
        let range = ScriptTextOffsets.nsRange(of: 2..<9, in: text)
        #expect(range == NSRange(location: 3, length: 7))
        #expect(ScriptTextOffsets.characters(of: range, in: text) == 2..<9)
    }

    @Test func aRangePastTheEndIsClamped() {
        #expect(ScriptTextOffsets.nsRange(of: 3..<40, in: "Hello") == NSRange(location: 3, length: 2))
        #expect(ScriptTextOffsets.nsRange(of: 9..<9, in: "Hello") == NSRange(location: 5, length: 0))
    }

    @Test func theChangeIsOnlyWhatDiffers() {
        let inserted = ScriptTextOffsets.change(from: "Talk more", to: "Talk [pause] more")
        #expect(inserted.removed == 5..<5)
        #expect(inserted.inserted == 5..<13)
        let replaced = ScriptTextOffsets.change(from: "One two three", to: "One 2 three")
        #expect(replaced.removed == 4..<7)
        #expect(replaced.inserted == 4..<5)
        let same = ScriptTextOffsets.change(from: "Same", to: "Same")
        #expect(same.removed.isEmpty && same.inserted.isEmpty)
    }

    /// Two emoji that share their first UTF-16 unit are still told apart whole.
    @Test func theChangeNeverSplitsAnEmoji() {
        let change = ScriptTextOffsets.change(from: "Hi 😀", to: "Hi 😃")
        #expect(change.removed == 3..<4)
        #expect(ScriptTextOffsets.nsRange(of: change.removed, in: "Hi 😀") == NSRange(location: 3, length: 2))
    }
}
