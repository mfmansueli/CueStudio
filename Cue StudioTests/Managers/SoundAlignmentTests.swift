//
//  SoundAlignmentTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Heard words and script words paired a few at a time by how they sound, and nothing paired that doesn't.
@Suite("Sound alignment")
struct SoundAlignmentTests {
    @Test func aNameHeardAsSeveralWordsPairsWithIt() {
        let blocks = SoundAlignment.blocks(["Jean", "Carlos", "disse", "que", "ela"], ["Giancarlo", "Fisichella"], least: 0.65)
        #expect(blocks.count == 1)
        #expect(blocks.first?.heard == 0..<5 && blocks.first?.written == 0..<2)
    }

    @Test func aWordSaidDifferentlyBesideAMishearingPairsWithNothing() {
        // "einen" was misheard for "Pfahl"? No: "Pfahl" was heard right; only "Gitley" sounds like "Gridley".
        let blocks = SoundAlignment.blocks(["Gitley", "danach"], ["Gridley", "oder"], least: 0.65)
        #expect(blocks.map(\.heard) == [0..<1] && blocks.map(\.written) == [0..<1])
    }

    @Test func whatIsNotAllowedNeverPairs() {
        let blocks = SoundAlignment.blocks(["2", "00", "6"], ["2006"], least: 0.1) { stretch in
            !stretch.contains { $0.contains(where: \.isNumber) }
        }
        #expect(blocks.isEmpty)
        #expect(SoundAlignment.blocks([], ["word"], least: 0.1).isEmpty)
    }
}
