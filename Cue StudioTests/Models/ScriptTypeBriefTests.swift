//
//  ScriptTypeBriefTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptType+Brief")
struct ScriptTypeBriefTests {
    @Test func emptyFieldsUseTheExamples() {
        let resolved = ScriptType.review.resolvedBrief([:])
        #expect(resolved["product"] == "Lumen desk lamp")
    }

    @Test func trailingPunctuationIsTrimmed() {
        let resolved = ScriptType.launch.resolvedBrief(["news": "Big drop!", "when": "Friday."])
        #expect(resolved["news"] == "Big drop")
        #expect(resolved["when"] == "Friday")
    }

    @Test func adTitleUsesTheBrandName() {
        #expect(ScriptType.ad.draftTitle(from: [:]) == "Oat & Co — sponsored")
    }

    @Test func listTitleCountsThePoints() {
        #expect(ScriptType.list.draftTitle(from: ["topic": "Desk tips", "items": "a, b"]) == "2 desk tips that work")
    }

    @Test func listDraftNumbersEachPoint() {
        let draft = ScriptType.list.draft(from: ["topic": "Morning habits", "items": "No phone, Write one goal"])
        let paragraphs = CueParser.paragraphs(in: draft)
        #expect(paragraphs.first == "2 morning habits that actually changed my life. [pause]")
        #expect(paragraphs.contains("Number one: no phone."))
        #expect(paragraphs.contains("Number two: write one goal."))
        #expect(paragraphs.last == "Which one are you trying first? Tell me in the comments.")
    }

    @Test func opinionQuestionKeepsASingleQuestionMark() {
        let draft = ScriptType.opinion.draft(from: ["ask": "What do you think?"])
        #expect(draft.contains("What do you think? [look at camera]"))
        #expect(!draft.contains("??"))
    }

    @Test func draftsFollowTheFormatStructure() {
        for type in ScriptType.allCases {
            let paragraphs = CueParser.paragraphs(in: type.draft(from: [:]))
            #expect(paragraphs.count >= type.structure.blocks.count - 1, "\(type) draft is too short")
        }
    }

    @Test(arguments: [
        ("No phone for 20 minutes", "no phone for 20 minutes"),
        ("TikTok changed", "TikTok changed"),
        ("I tried it", "I tried it"),
        ("USB mics", "USB mics"),
        ("iPhone only", "iPhone only"),
    ])
    func lowercasedFirstKeepsNamesAndAcronyms(input: String, expected: String) {
        #expect(ScriptType.lowercasedFirst(input) == expected)
    }
}
