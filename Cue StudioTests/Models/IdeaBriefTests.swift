//
//  IdeaBriefTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// One inspiration as one brief: what "Use this idea" puts in the field, never past its 200 characters, and what of it still stands once the creator
/// has changed the text (their words win over the card's).
@Suite("Idea brief")
struct IdeaBriefTests {
    private let brief = IdeaBrief(
        subject: "Why saving feels harder than spending", angle: "Explain one small habit that makes saving easier.",
        openingLine: "Saving isn’t just about willpower. It’s about what you make automatic.", language: "en", angleKind: "fact", topicKey: "finance"
    )

    // MARK: - In the field

    @Test func theFieldGetsTheTitleTheAngleAndTheOpeningLineEachOnItsLine() {
        #expect(brief.composerText == """
            Why saving feels harder than spending
            Angle: Explain one small habit that makes saving easier.
            Open with: “Saving isn’t just about willpower. It’s about what you make automatic.”
            """)
    }

    @Test func aBriefTooLongForTheFieldLosesSecondSentencesFirstThenWordsAndNeverHalfAWord() {
        let long = IdeaBrief(
            subject: "The morning routine that finally made my whole week feel lighter",
            angle: "Walk through each step of a calm morning and say why every single one of them matters for the rest of the day.",
            openingLine: "If your mornings feel rushed and chaotic, you are not alone at all. Here is a slower way to begin that anyone can try tomorrow."
        )
        let text = long.composerText
        #expect(text.count <= IdeaPromptDraft.maxCharacters)
        #expect(text.hasPrefix("The morning routine that finally made my whole week feel lighter\n"), "the title is never cut")
        let fitted = long.fitted()
        #expect(!fitted.openingLine.contains("Here is"), "the second sentence goes before any word of the first")
        let words = Set(long.openingLine.split(separator: " ").map { $0.trimmingCharacters(in: .punctuationCharacters) })
        let cut = fitted.openingLine.replacingOccurrences(of: "…", with: "").split(separator: " ").map { $0.trimmingCharacters(in: .punctuationCharacters) }
        #expect(cut.allSatisfy(words.contains), "whole words only: \(fitted.openingLine)")
        #expect(fitted.openingLine.count > 20 && fitted.angle.count > 20, "neither part is cut to nothing")
        #expect(text == fitted.composerText, "the card shows what the field gets")
    }

    @Test func anAngleOrALineWithNothingInItHasNoLine() {
        var partial = brief
        partial.angle = ""
        #expect(partial.composerText == "Why saving feels harder than spending\nOpen with: “Saving isn’t just about willpower. It’s about what you make automatic.”")
        partial.openingLine = ""
        #expect(partial.composerText == "Why saving feels harder than spending")
    }

    @Test func aBriefSavedBeforeItHadItsNewFieldsStillReads() throws {
        let old = Data(#"{"subject":"Desk stretches","angle":"Show three.","openingLine":"Sit up."}"#.utf8)
        let decoded = try JSONDecoder().decode(IdeaBrief.self, from: old)
        #expect(decoded.subject == "Desk stretches" && decoded.angleKind == nil && decoded.topicKey == nil && decoded.language == nil)
    }

    // MARK: - What still stands

    @Test func theTextAsItWasKeepsTheWholeBrief() {
        #expect(brief.standing(in: brief.composerText) == brief)
    }

    @Test func punctuationCaseAndALineMovedKeepIt() {
        let edited = """
            Open with: "saving isn't just about willpower, it's about what you make automatic"
            why saving feels harder than spending!
            angle - explain one small habit that makes saving easier
            """
        #expect(brief.standing(in: edited) == brief)
    }

    @Test func aWordChangedKeepsThePart() {
        let edited = brief.composerText.replacingOccurrences(of: "small habit", with: "tiny habit")
        #expect(brief.standing(in: edited)?.angle == brief.angle)
    }

    @Test func anAngleRewrittenGoesButTheIdeaAndItsLineStay() {
        let edited = """
            Why saving feels harder than spending
            Angle: compare apps that round up your purchases
            Open with: “Saving isn’t just about willpower. It’s about what you make automatic.”
            """
        let kept = brief.standing(in: edited)
        #expect(kept?.subject == brief.subject)
        #expect(kept?.angle == "")
        #expect(kept?.openingLine == brief.openingLine)
        #expect(kept?.angleKind == "fact" && kept?.topicKey == "finance", "what it was is still known, for the taste")
    }

    @Test func anOpeningLineDeletedGoes() {
        let edited = "Why saving feels harder than spending\nAngle: Explain one small habit that makes saving easier."
        #expect(brief.standing(in: edited)?.openingLine == "")
    }

    @Test func anotherIdeaAltogetherDropsTheBrief() {
        #expect(brief.standing(in: "My trip to Lisbon on a budget") == nil)
        #expect(brief.standing(in: "") == nil)
    }

    @Test func aTitleRewrittenDropsTheBriefEvenWithTheLineStillThere() {
        let edited = "How I paid off my car\nOpen with: “Saving isn’t just about willpower. It’s about what you make automatic.”"
        #expect(brief.standing(in: edited) == nil)
    }

    @Test func aLanguageWithoutSpacesIsComparedByItsLetters() {
        let japanese = IdeaBrief(subject: "貯金が難しい理由", angle: "貯金を楽にする小さな習慣を説明する。", openingLine: "貯金は意志の力だけではありません。")
        #expect(japanese.standing(in: japanese.composerText) == japanese)
        let edited = "貯金が難しい理由\n角度：おすすめのアプリを比べる"
        #expect(japanese.standing(in: edited)?.subject == japanese.subject)
        #expect(japanese.standing(in: edited)?.angle == "")
        #expect(japanese.standing(in: "旅行の準備") == nil)
    }
}
