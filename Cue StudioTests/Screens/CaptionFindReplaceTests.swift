//
//  CaptionFindReplaceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Finding a word in the caption lines and replacing it: capitals and width don't matter, accents do; matches never overlap;
/// one match or all of them change.
@Suite("Caption find and replace")
struct CaptionFindReplaceTests {
    @Test func capitalsAndWidthAreIgnoredButAccentsAreNot() {
        #expect(CaptionFindReplace.count(of: "cue", in: "Cue makes CUE videos") == 2)
        #expect(CaptionFindReplace.count(of: "ＣＵＥ", in: "Cue") == 1)
        // "e" and "é" are different words in Portuguese, French, Spanish…
        #expect(CaptionFindReplace.count(of: "e", in: "é") == 0)
        #expect(CaptionFindReplace.count(of: "você", in: "Você e você") == 2)
    }

    @Test func matchesDontOverlapAndEmptyFindsNothing() {
        #expect(CaptionFindReplace.count(of: "aa", in: "aaaa") == 2)
        #expect(CaptionFindReplace.count(of: "  ", in: "a  b") == 0)
        #expect(CaptionFindReplace.ranges(of: "", in: "anything").isEmpty)
    }

    @Test func oneMatchOrAllOfThemAreReplaced() {
        let text = "the cat and the dog and the bird"
        #expect(CaptionFindReplace.replacing("the", with: "a", in: text, occurrence: 1) == "the cat and a dog and the bird")
        #expect(CaptionFindReplace.replacing("THE", with: "a", in: text) == "a cat and a dog and a bird")
        // No such match: the text as it was.
        #expect(CaptionFindReplace.replacing("the", with: "a", in: text, occurrence: 5) == text)
        #expect(CaptionFindReplace.replacing("fish", with: "a", in: text) == text)
    }

    @Test func aWordReplacedByNothingLeavesNoDoubleSpace() {
        #expect(CaptionFindReplace.replacing("um", with: "", in: "So um this is um it") == "So this is it")
        #expect(CaptionFindReplace.replacing("um", with: "", in: "um okay") == "okay")
    }

    @Test func matchesAreListedInLineOrderWithTheirContext() {
        let first = CaptionCue(text: "Cue is cue", start: 0, end: 1)
        let second = CaptionCue(text: "Nothing here", start: 1, end: 2)
        let third = CaptionCue(text: "Try Cue", start: 2, end: 3)
        let matches = CaptionFindReplace.matches(of: "cue", in: [first, second, third])
        #expect(matches.map(\.cueID) == [first.id, first.id, third.id])
        #expect(matches.map(\.occurrence) == [0, 1, 0])
        #expect(matches[1].before == "Cue is " && matches[1].found == "cue" && matches[1].after.isEmpty)
        #expect(Set(matches.map(\.id)).count == 3)
    }

    @Test func rightToLeftAndUnspacedWritingIsFound() {
        #expect(CaptionFindReplace.count(of: "مرحبا", in: "مرحبا بكم مرحبا") == 2)
        #expect(CaptionFindReplace.replacing("東京", with: "大阪", in: "東京へ行く") == "大阪へ行く")
    }
}
