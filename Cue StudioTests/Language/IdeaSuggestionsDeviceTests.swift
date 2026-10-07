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
/// "Bureaucracy", and "Languages" with "Italian"), asked for three times in a row the way the card does, each told what came before. What is printed is
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
        var shown: [String] = []
        for batch in 0..<3 {
            let started = ContinuousClock.now
            let ideas = try await service.suggestIdeas(about: topics, language: .english, voice: nil, avoiding: shown, round: batch)
            let seconds = started.duration(to: .now).inSeconds
            print(String(format: "SUGGEST batch %d: %.0f s, %d ideas", batch, seconds, ideas.count))
            for idea in ideas { print("SUGGEST   \(idea.meta) · \(idea.title)") }
            let again = ideas.map(\.title).filter { title in shown.contains { $0.caseInsensitiveCompare(title) == .orderedSame } }
            #expect(again.isEmpty, "Ideas came back twice: \(again)")
            #expect(ideas.count >= 3)
            #expect(seconds < 40, "A batch took \(Int(seconds)) s")
            shown += ideas.map(\.title)
            try await Task.sleep(for: .seconds(3))
        }
        #expect(Set(shown.map { $0.lowercased() }).count == shown.count)
    }
}
