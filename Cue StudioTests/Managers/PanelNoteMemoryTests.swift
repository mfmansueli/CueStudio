//
//  PanelNoteMemoryTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The editor's teaching notes show the first three times, then stay away, on this iPhone; each note counts on its own.
@MainActor
@Suite("Panel note memory")
struct PanelNoteMemoryTests {
    @Test func aTeachingNoteGoesAfterThreeReads() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let memory = PanelNoteMemory(defaults: defaults.defaults)
        let note = "Drag a point up to speed up, down to slow down."
        for _ in 0..<PanelNoteMemory.lessons {
            #expect(memory.teaches(note))
            memory.read(note)
        }
        #expect(!memory.teaches(note))
        #expect(memory.teaches("Drag the box or pull its corners on the video."), "Another note still teaches")
        #expect(!PanelNoteMemory(defaults: defaults.defaults).teaches(note), "Kept across launches")
    }
}
