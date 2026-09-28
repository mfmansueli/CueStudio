//
//  ScriptBlocksTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptBlocks")
struct ScriptBlocksTests {
    private let text = "Short hook.\n\nFirst body line.\n\nSecond body line.\n\nFollow for more."

    @Test func labelsParagraphsWithTheStructure() {
        let blocks = ScriptBlocks.blocks(for: text, structure: .generic, speed: 1)
        #expect(blocks.map(\.label) == ["Hook", "Body", "Body", "CTA"])
    }

    @Test func repeatedLabelsAreShownOnce() {
        let blocks = ScriptBlocks.blocks(for: text, structure: .generic, speed: 1)
        #expect(blocks.map(\.showsLabel) == [true, true, false, true])
    }

    @Test func summariesMergeConsecutiveBlocks() {
        let blocks = ScriptBlocks.blocks(for: text, structure: .generic, speed: 1)
        let summaries = ScriptBlocks.summaries(of: blocks)
        #expect(summaries.map(\.label) == ["Hook", "Body", "CTA"])
        #expect(summaries[1].seconds == blocks[1].seconds + blocks[2].seconds)
        #expect(summaries[0].isOpening)
    }

    @Test func longHookIsFlagged() {
        // 43 words take 12 seconds at 1.0× (215 words a minute).
        let blocks = ScriptBlocks.blocks(for: TestData.words(43) + "\n\nBody.", structure: .generic, speed: 1)
        #expect(ScriptBlocks.hookOverrun(in: blocks, structure: .generic) == 12)
    }

    @Test func shortHookIsFine() {
        let blocks = ScriptBlocks.blocks(for: text, structure: .generic, speed: 1)
        #expect(ScriptBlocks.hookOverrun(in: blocks, structure: .generic) == nil)
    }

    @Test func seriousFormatsHaveNoHookWarning() {
        let structure = ScriptType.apology.structure
        let blocks = ScriptBlocks.blocks(for: TestData.words(20), structure: structure, speed: 1)
        #expect(ScriptBlocks.hookOverrun(in: blocks, structure: structure) == nil)
    }
}
