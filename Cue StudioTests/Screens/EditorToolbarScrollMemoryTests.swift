//
//  EditorToolbarScrollMemoryTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Where the toolbar comes back scrolled (`EditorToolbarScrollMemory`): the main tools where they were left, an item's where its
/// kind was left, another kind at its first tool.
@Suite("Toolbar scroll memory")
@MainActor
struct EditorToolbarScrollMemoryTests {
    @Test func theMainToolsComeBackWhereTheyWereLeft() {
        var memory = EditorToolbarScrollMemory()
        #expect(memory.enter(.main) == nil)
        memory.scrolled(to: "filters", in: .main)
        // A clip's tools, scrolled, then back to the main ones.
        #expect(memory.enter(.clip) == nil)
        memory.scrolled(to: "reorder", in: .clip)
        #expect(memory.enter(.main) == "filters")
        // A panel (no toolbar) and back: the same.
        #expect(memory.enter(.main) == "filters")
    }

    @Test func anItemsToolsKeepTheirPlaceForItsKindAndStartOverForAnother() {
        var memory = EditorToolbarScrollMemory()
        _ = memory.enter(.clip)
        memory.scrolled(to: "adjust", in: .clip)
        // Another clip picked (the same kind), or back from one of its panels.
        #expect(memory.enter(.clip) == "adjust")
        // A text: its tools from the first.
        #expect(memory.enter(.text) == nil)
        memory.scrolled(to: "captions", in: .text)
        #expect(memory.enter(.clip) == nil, "the clip's place went with the other kind")
    }

    @Test func anItemPickedAgainFromTheMainToolsStartsAtItsFirstTool() {
        var memory = EditorToolbarScrollMemory()
        _ = memory.enter(.clip)
        memory.scrolled(to: "adjust", in: .clip)
        _ = memory.enter(.main)
        #expect(memory.enter(.clip) == nil)
        // A menu is its own kind too.
        #expect(memory.enter(.menu(.audio)) == nil)
    }
}
