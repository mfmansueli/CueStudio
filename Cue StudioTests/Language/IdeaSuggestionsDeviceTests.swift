//
//  IdeaSuggestionsDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// "↻ another idea" on a real iPhone: the card's ideas for a creator who holds only their own topics (a typed "Daily Routine" with the subtopic
/// "Bureaucracy", and "Languages" with "Italian") who wrote about Italian forms and planning with AI, asked for four times in a row the way the card
/// does, the creator liking a myth about languages from the second batch on. What is printed is
/// what the creator would see: the seconds each batch took and the ideas, and whether any came back twice. Opt-in, on a device with Apple Intelligence,
/// unlocked and awake: `CUE_DEVICE=<iPhone> scripts/test.sh device IdeaSuggestionsDeviceTests`.
@MainActor
@Suite("Suggested ideas on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct IdeaSuggestionsDeviceTests {
    @Test func anotherIdeaNeverRunsOut() async throws {
        KeepScreenAwake.enable()
        let service = ScriptAIService()
        guard service.availability.onDevice else { try Test.cancel("Apple Intelligence isn't available on this device") }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        let topics = [
            IdeaTopic(name: "Daily Routine", label: "Daily Routine", niche: nil, subtopics: ["Bureaucracy"]),
            IdeaTopic(name: "language learning", label: "Languages", niche: nil, subtopics: ["Italian"]),
        ]
        // What the creator wrote lately: the ideas grow from it.
        let inspiration = ["Why filling Italian bureaucracy forms takes me three tries", "How I plan my week with AI and it still goes wrong"]
        var taste = IdeaTaste()
        var seen: [IdeaSimilarityKey] = []
        var titles: [String] = []
        for batch in 0..<4 {
            // From the second batch on, the creator has sent a myth about languages: what they like is asked for again.
            if batch == 1 {
                var liked = ThemeIdea(title: "liked", kind: "Myth-busting", length: .minute1, niche: .lifestyle, topic: "Languages")
                liked.angle = IdeaAngle.myth.rawValue
                taste.sent(liked)
                taste.sent(liked)
            }
            let slots = taste.slots(round: batch, among: topics)
            let started = ContinuousClock.now
            let ideas = try await service.suggestIdeas(slots: slots, language: .english, voice: nil, inspiration: inspiration)
            let seconds = started.duration(to: .now).inSeconds
            print(String(format: "SUGGEST batch %d: %.0f s, %d ideas, angles %@", batch, seconds, ideas.count, slots.map(\.angle.rawValue).joined(separator: ",")))
            for idea in ideas { print("SUGGEST   \(idea.meta) · \(idea.title)") }
            let again = ideas.filter { idea in seen.contains { IdeaSimilarity.areAlike($0.words, IdeaSimilarity.words(in: idea.title)) } }.map(\.title)
            // The card drops a reworded idea (`IdeaSuggestionService`); asked for directly, one in twenty-four may come back in other words.
            #expect(again.count <= 1, "Ideas came back twice or reworded: \(again)")
            #expect(ideas.count >= 3)
            #expect(seconds < 40, "A batch took \(Int(seconds)) s")
            if batch >= 1 { #expect(slots.map(\.angle).contains(.myth), "the angle they sent is asked for again") }
            seen += ideas.map { IdeaSimilarityKey(words: IdeaSimilarity.words(in: $0.title)) }
            titles += ideas.map(\.title)
            try await Task.sleep(for: .seconds(3))
        }
        #expect(Set(titles.map { $0.lowercased() }).count == titles.count)
    }

    private struct IdeaSimilarityKey {
        let words: Set<String>
    }
}
