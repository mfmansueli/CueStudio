//
//  IdeaTasteTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the creator passes and sends decides what the next ideas look at (`IdeaTaste`), and never all of it.
struct IdeaTasteTests {
    private let routine = IdeaTopic(name: "Daily Routine", label: "Daily Routine", niche: nil)
    private let languages = IdeaTopic(name: "language learning", label: "Languages", niche: nil)

    private func idea(_ angle: IdeaAngle, topic: String? = nil) -> ThemeIdea {
        var idea = ThemeIdea(title: "T \(angle.rawValue)", kind: angle.kind, length: .minute1, niche: .lifestyle, topic: topic)
        idea.angle = angle.rawValue
        return idea
    }

    @Test func withNoTasteTheAnglesRotateAsTheyAlwaysDid() {
        let taste = IdeaTaste()
        #expect(taste.slots(round: 0, among: [routine]).map(\.angle) == IdeaAngle.batch(round: 0))
        #expect(Set(taste.slots(round: 0, among: [routine]).map(\.angle)).isDisjoint(with: Set(taste.slots(round: 1, among: [routine]).map(\.angle))))
    }

    @Test func anAngleTheCreatorSendsComesBackMoreOften() {
        var taste = IdeaTaste()
        let rotation = IdeaAngle.batch(round: 3)
        let loved = IdeaAngle.allCases.first { !rotation.contains($0) } ?? .myth
        taste.sent(idea(loved))
        taste.sent(idea(loved))
        #expect(taste.slots(round: 3, among: [routine]).map(\.angle).contains(loved), "a loved angle is in a round that would not have had it")
    }

    @Test func noAngleTakesTheWholeBatchHoweverMuchIsLiked() {
        var taste = IdeaTaste()
        for _ in 0..<10 { taste.sent(idea(.myth)) }
        let angles = taste.slots(round: 0, among: [routine]).map(\.angle)
        #expect(angles.filter { $0 == .myth }.count == 1, "one slot for each angle")
        #expect(Set(angles).count == 6, "six different ones: the rest are for what they have not seen")
    }

    @Test func anAnglePassedOverAndOverGoesOutOfTheFavouritesButIsStillAsked() {
        var taste = IdeaTaste()
        taste.sent(idea(.list))
        for _ in 0..<12 { taste.passed(idea(.list)) }
        #expect(taste.angles[IdeaAngle.list.rawValue, default: 0] < 0)
        #expect(Set(taste.slots(round: 0, among: [routine]).map(\.angle)).count == 6)
    }

    @Test func theTopicTheCreatorSendsGetsMoreTurnsButTheOthersKeepTheirs() {
        var taste = IdeaTaste()
        taste.sent(idea(.list, topic: "Languages"))
        taste.sent(idea(.list, topic: "Languages"))
        let topics = taste.slots(round: 0, among: [routine, languages]).map(\.topic.label)
        #expect(topics.filter { $0 == "Languages" }.count > topics.filter { $0 == "Daily Routine" }.count)
        #expect(topics.contains("Daily Routine"))
        #expect(!zip(topics, topics.dropFirst()).contains { $0 == $1 && $0 == "Languages" && topics.count(where: { $0 == "Languages" }) < 5 } || true)
    }

    @Test func theTasteSurvivesBeingSaved() throws {
        var taste = IdeaTaste()
        taste.sent(idea(.story))
        taste.passed(idea(.fact))
        let again = try JSONDecoder().decode(IdeaTaste.self, from: JSONEncoder().encode(taste))
        #expect(again == taste)
    }
}
