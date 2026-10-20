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
        let blocks = ScriptBlocks.blocks(for: text, structure: .generic)
        #expect(blocks.map(\.label) == ["Hook", "Body", "Body", "CTA"])
    }

    @Test func repeatedLabelsAreShownOnce() {
        let blocks = ScriptBlocks.blocks(for: text, structure: .generic)
        #expect(blocks.map(\.showsLabel) == [true, true, false, true])
    }

    @Test func summariesMergeConsecutiveBlocks() {
        let blocks = ScriptBlocks.blocks(for: text, structure: .generic)
        let summaries = ScriptBlocks.summaries(of: blocks)
        #expect(summaries.map(\.label) == ["Hook", "Body", "CTA"])
        #expect(summaries[1].seconds == blocks[1].seconds + blocks[2].seconds)
        #expect(summaries[0].isOpening)
    }

    @Test func longHookIsFlagged() {
        // 30 words take 12 seconds at the natural pace (150 words a minute).
        let blocks = ScriptBlocks.blocks(for: TestData.words(30) + "\n\nBody.", structure: .generic)
        #expect(ScriptBlocks.hookOverrun(in: blocks, structure: .generic) == 12)
    }

    @Test func shortHookIsFine() {
        let blocks = ScriptBlocks.blocks(for: text, structure: .generic)
        #expect(ScriptBlocks.hookOverrun(in: blocks, structure: .generic) == nil)
    }

    @Test func seriousFormatsHaveNoHookWarning() {
        let structure = ScriptType.apology.structure
        let blocks = ScriptBlocks.blocks(for: TestData.words(20), structure: structure)
        #expect(ScriptBlocks.hookOverrun(in: blocks, structure: structure) == nil)
    }
}
