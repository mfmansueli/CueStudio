//
//  ScriptStructureTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptStructure")
struct ScriptStructureTests {
    private func labels(_ structure: ScriptStructure, count: Int) -> [String] {
        (0..<count).map { structure.blockLabel(forParagraph: $0, of: count) }
    }

    @Test func genericOpensWithHookAndClosesWithCTA() {
        #expect(labels(.generic, count: 5) == ["Hook", "Body", "Body", "Body", "CTA"])
    }

    @Test func singleParagraphIsTheHook() {
        #expect(labels(.generic, count: 1) == ["Hook"])
    }

    @Test func twoParagraphsAreHookAndClose() {
        #expect(labels(.generic, count: 2) == ["Hook", "CTA"])
    }

    @Test func adWalksThroughItsMiddleBlocks() {
        #expect(labels(ScriptType.ad.structure, count: 5) == ["Hook", "Problem", "Product", "Proof", "Offer"])
    }

    @Test func onlyApologyIsSerious() {
        #expect(ScriptType.allCases.filter { $0.structure.isSerious } == [.apology])
    }
}
