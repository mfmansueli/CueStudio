//
//  FactReviewTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Decision 9: "I checked" records the review of one version; an AI rewrite that changes the words brings the reminder back, and an Undo
/// to the reviewed words takes it away again.
@MainActor
@Suite("Fact review")
struct FactReviewTests {
    @Test func aReviewCoversOnlyTheWordsReviewed() {
        let review = FactReview(text: "Coffee has 95 mg of caffeine.", version: 3, date: TestData.now)
        #expect(review.covers("Coffee has 95 mg of caffeine."))
        #expect(!review.covers("Coffee has 200 mg of caffeine."))
        #expect(FactReview.digest(of: "same") == FactReview.digest(of: "same"), "The same on every launch")
    }

    @Test func checkedRecordsTheVersionAndTheDate() throws {
        var script = TestData.script(version: 4)
        script.factCheck = true
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        library.markFactChecked(script.id)
        let review = try #require(library.script(id: script.id)?.factReview)
        #expect(review.version == 4 && review.date == TestData.now && review.covers(script.text))
        #expect(library.script(id: script.id)?.factCheck == false)
    }

    @Test func aRewriteBringsTheReminderBackAndAnUndoTakesItAway() {
        var script = TestData.script()
        script.factCheck = true
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        library.markFactChecked(script.id)
        library.update(script.id) { $0.text = "A rewritten claim: 3 in 4 people sleep badly." }
        library.flagForFactCheckAfterRewrite(script.id)
        #expect(library.script(id: script.id)?.factCheck == true)
        library.update(script.id) { $0.text = script.text }
        library.clearFactCheckIfReviewed(script.id)
        #expect(library.script(id: script.id)?.factCheck == false)
    }

    /// A script that never needed checking, or that was only hidden, is never flagged by a rewrite: nothing was recorded as checked.
    @Test func withoutAReviewARewriteFlagsNothing() {
        let script = TestData.script()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]), now: { TestData.now })
        library.load()
        library.update(script.id) { $0.text = "Something new." }
        library.flagForFactCheckAfterRewrite(script.id)
        #expect(library.script(id: script.id)?.factCheck == false)
        #expect(library.script(id: script.id)?.factReview == nil)
    }
}
