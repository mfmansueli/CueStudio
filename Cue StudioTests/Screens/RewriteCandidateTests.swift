//
//  RewriteCandidateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The rewrite waiting for "Use": it goes where the old words were, wherever they are by then.
@Suite("Rewrite candidate")
struct RewriteCandidateTests {
    private func candidate(original: String, at start: Int) -> RewriteCandidate {
        RewriteCandidate(action: .shorter, original: original, rewritten: "SHORT", offsets: start..<(start + original.count))
    }

    @Test func itReplacesTheSelectionWhereItWas() {
        #expect(candidate(original: "second line", at: 11).applied(to: "first line\nsecond line\nthird") == "first line\nSHORT\nthird")
    }

    @Test func ifTheTextMovedItFindsTheOldWordsAgain() {
        // Something was typed in front of it meanwhile.
        #expect(candidate(original: "second line", at: 11).applied(to: "A new start. first line\nsecond line") == "A new start. first line\nSHORT")
    }

    @Test func ifTheOldWordsAreGoneTheTextIsLeftAsItIs() {
        #expect(candidate(original: "second line", at: 11).applied(to: "nothing alike") == "nothing alike")
    }

    @Test func theFourRewritesRunTheToolsOfImproveScript() {
        #expect(SelectionAction.allCases.map(\.tool) == [.moreHuman, .shorterAndDirect, .moreEnergy, .inMyVoice])
        #expect(SelectionAction.allCases.count == 4 && SelectionAction.allCases.allSatisfy { !$0.label.isEmpty && !$0.title.isEmpty })
    }
}
