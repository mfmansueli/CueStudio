//
//  CoverTitleSuggestionsTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The Title step never offers the title the cover already has, whatever its case or spacing.
@Suite("Cover title suggestions")
struct CoverTitleSuggestionsTests {
    private let suggestions = ["3 morning habits", "How I wake up at 5", "The one habit"]

    @Test func theCurrentTitleIsNotOffered() {
        #expect(CoverTitleSuggestions.offered(suggestions, title: "3 morning habits") == ["How I wake up at 5", "The one habit"])
    }

    @Test func caseAndSpacingDontMatter() {
        #expect(CoverTitleSuggestions.offered(suggestions, title: "  3 MORNING   habits\n") == ["How I wake up at 5", "The one habit"])
        #expect(CoverTitleSuggestions.offered(["  how i wake  UP at 5 "], title: "How I wake up at 5").isEmpty)
    }

    @Test func anEmptyOrDifferentTitleKeepsThemAll() {
        #expect(CoverTitleSuggestions.offered(suggestions, title: "") == suggestions)
        #expect(CoverTitleSuggestions.offered(suggestions, title: "   ") == suggestions)
        #expect(CoverTitleSuggestions.offered(suggestions, title: "3 morning habits!") == suggestions)
    }
}
