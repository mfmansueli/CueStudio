//
//  IdeaTiesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What ideas are tied to besides their topic (`IdeaSignals`, `IdeaTie`): a day coming up, a video the creator posted, a comment they answered,
/// in a few slots of a batch and never all; the starters without the model; the topic carried to the script; the taste ordering the starters.
struct IdeaTiesTests {
    private let beauty = IdeaTopic(name: Niche.beauty.promptName, label: Niche.beauty.label, niche: .beauty)
    private let mothersDay = IdeaOccasion(kind: .mothersDay, date: Date(timeIntervalSince1970: 1_778_382_000), isApproximate: false)

    private var signals: IdeaSignals {
        IdeaSignals(posted: ["Sunscreen under makeup", "My 5-minute routine"], comments: ["Does SPF 30 last all day?"], occasions: [mothersDay])
    }

    // MARK: - Slots

    @Test func aRoundTiesAFewSlotsAndLeavesTheRestToTheTopics() {
        let slots = IdeaTaste().slots(round: 0, among: [beauty])
        let even = signals.tie(slots, round: 0)
        #expect(even[1].tie == .occasion(mothersDay))
        #expect(even.compactMap(\.tie).count == 1)
        let odd = signals.tie(slots, round: 1)
        #expect(odd[0].tie == .followUp("Sunscreen under makeup"))
        let third = signals.tie(slots, round: 2)
        #expect(third[2].tie == .comment("Does SPF 30 last all day?"))
        #expect(third[1].tie == .occasion(mothersDay))
        #expect(signals.tie(slots, round: 3)[0].tie == .followUp("My 5-minute routine"), "the next video in turn")
        #expect(IdeaSignals().tie(slots, round: 0) == slots, "nothing to tie: the slots as they were")
    }

    @Test func theModelIsAskedForTheTieInTheSlotsOwnLine() {
        let slots = signals.tie(IdeaTaste().slots(round: 1, among: [beauty]), round: 1)
        let prompt = ScriptPromptBuilder.themesPrompt(slots: slots, asBriefs: true)
        #expect(prompt.contains("1. \(slots[0].angle.ask) about beauty and skincare, as a follow-up to their video “Sunscreen under makeup”"))
        #expect(prompt.contains("the title or angle names the exact subject"))
        let occasion = signals.tie(IdeaTaste().slots(round: 0, among: [beauty]), round: 0)
        #expect(ScriptPromptBuilder.themesPrompt(slots: occasion, asBriefs: true).contains(", tied to Mother's Day, on May"))
    }

    @Test func anIdeaKeepsItsTieAndItsTopicFromTheSlot() throws {
        var slot = IdeaSlot(angle: .tutorial, topic: beauty)
        slot.tie = .occasion(mothersDay)
        let answer = IdeaBriefReader.Answer(title: "A gift-ready skincare kit", angle: "Build a simple kit.", openingLine: "Here's a kit anyone can make.")
        let idea = try #require(IdeaBriefReader.idea(from: answer, slot: slot, language: "en"))
        #expect(idea.tie == .occasion(mothersDay))
        #expect(idea.brief?.topic == "beauty and skincare")
        #expect(idea.tie?.cardLine.contains(mothersDay.name) == true)
    }

    // MARK: - The script

    @Test func theScriptStaysInsideTheTopicTheIdeaWasSuggestedFor() {
        let brief = IdeaBrief(subject: "How to choose products without surprises", angle: "Read the label first.", openingLine: "Look at the name.",
                              topicKey: Niche.beauty.rawValue, topic: "beauty and skincare")
        #expect(ScriptPromptBuilder.briefTopicRule(brief) == "The idea was suggested for the creator's topic “beauty and skincare”: keep the video inside that topic.")
        var old = brief
        old.topic = nil
        #expect(ScriptPromptBuilder.briefTopicRule(old) == nil, "kept by an older version: nothing added")
    }

    // MARK: - Without the model

    @Test func theStartersTiedToTheCreatorComeFirst() {
        let tied = ThemeCatalog.tied(to: signals, topic: beauty)
        #expect(tied.map(\.tie) == [.occasion(mothersDay), .followUp("Sunscreen under makeup"), .followUp("My 5-minute routine")])
        #expect(tied.allSatisfy { $0.brief?.topic == "beauty and skincare" && $0.niche == .beauty })
        #expect(ThemeCatalog.tied(to: IdeaSignals(comments: ["A question"]), topic: beauty).isEmpty, "a comment alone has no starter")
    }

    @Test func aTypedTopicHasAStarterForEveryAngle() {
        let typed = IdeaTopic(name: "Handmade ceramics", label: "Handmade ceramics", niche: nil)
        let starters = ThemeCatalog.ideas(for: typed)
        #expect(Set(starters.compactMap(\.brief?.angleKind)) == Set(IdeaAngle.allCases.map(\.rawValue)))
        #expect(Set(starters.map(\.id)).count == starters.count)
    }

    @Test func theTasteOrdersTheStartersWithoutHidingTheRest() {
        var taste = IdeaTaste()
        var myth = ThemeIdea(title: "M", kind: "", length: .minute1, niche: .beauty)
        myth.angle = IdeaAngle.myth.rawValue
        var list = ThemeIdea(title: "L", kind: "", length: .minute1, niche: .beauty)
        list.angle = IdeaAngle.list.rawValue
        var fact = ThemeIdea(title: "F", kind: "", length: .minute1, niche: .beauty)
        fact.angle = IdeaAngle.fact.rawValue
        var tool = ThemeIdea(title: "T", kind: "", length: .minute1, niche: .beauty)
        tool.angle = IdeaAngle.tool.rawValue
        taste.sent(myth)
        taste.sent(tool)
        taste.passed(list)
        #expect(taste.ordered([list, fact, myth, tool]).map(\.title) == ["M", "F", "T", "L"], "liked and not, in turn; passed last")
        #expect(IdeaTaste().ordered([list, fact, myth]).map(\.title) == ["L", "F", "M"], "no taste yet: as written")
    }

    // MARK: - Signals

    @Test func theSignalsAreTheNewestSharedVideosAndAnsweredComments() {
        let old = TestData.script(title: "Old video", updatedAt: TestData.now.addingTimeInterval(-86_400))
        var new = TestData.script(title: "New video")
        new.comment = ScriptComment(author: "@ana", text: "And for oily skin?")
        let oldTake = TestData.take(scriptID: old.id)
        let newTake = TestData.take(scriptID: new.id)
        let records = [
            ShareRecord(takeID: oldTake.id, date: TestData.now.addingTimeInterval(-86_400), topic: nil),
            ShareRecord(takeID: newTake.id, date: TestData.now, topic: nil),
            ShareRecord(takeID: UUID(), date: TestData.now, topic: nil),
        ]
        let read = IdeaSignals.read(records: records, takes: [oldTake, newTake], scripts: [old, new])
        #expect(read.posted == ["New video", "Old video"])
        #expect(read.comments == ["And for oily skin?"])
        #expect(read.occasions.isEmpty, "worked out apart, once a day")
    }
}
