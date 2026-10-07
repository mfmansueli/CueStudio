//
//  CreatorDayDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// A creator's session as the pieces fit together, on a real iPhone, with the voice profile found on the owner's: the card suggests ideas that grow from what
/// they noted in the Logbook, they tap "↻" and send one, the script that comes back is about that idea (not about their usual topics), it comes in seconds,
/// and the tools of "Improve script" do what they say to it. What is printed is the table the creator would feel: seconds and what came back. Opt-in, on a
/// device with Apple Intelligence, unlocked and awake: `CUE_DEVICE=<iPhone> scripts/test.sh device CreatorDayDeviceTests`.
@MainActor
@Suite("A creator's day on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct CreatorDayDeviceTests {
    private struct Setup {
        let writer: ScriptAIService
        let profile: CreatorProfileService
        let defaults: TestDefaults
        let notes: [LogbookEntry]
    }

    private func setup() throws -> Setup {
        KeepScreenAwake.enable()
        let writer = ScriptAIService()
        guard writer.availability.onDevice else { try Test.cancel("Apple Intelligence isn't available on this device") }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        let defaults = TestDefaults()
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(IdeaRelevanceDeviceTests.ownerProfile.utf8))
        let notes = [LogbookEntry(text: "Why filling Italian bureaucracy forms takes me three tries", createdAt: .now)]
        return Setup(writer: writer, profile: profile, defaults: defaults, notes: notes)
    }

    private func words(_ text: String) -> Int { ReadTime.wordCount(in: CueParser.stripCues(text)) }

    @Test func theCardSuggestsAndTheScriptIsAboutTheIdeaSent() async throws {
        let setup = try setup()
        defer { setup.defaults.tearDown() }
        let notes = setup.notes
        let suggestions = IdeaSuggestionService(
            writer: setup.writer, profile: setup.profile, interfaceLanguage: { .english },
            inspiration: { IdeaInspiration.recent(scripts: [], notes: notes) }, notes: { notes }, defaults: setup.defaults.defaults
        )
        let asked = ContinuousClock.now
        await suggestions.refill()
        print(String(format: "DAY ideas: %.0f s, %d ideas", asked.duration(to: .now).inSeconds, suggestions.pool.count))
        #expect(suggestions.pool.count >= 4)
        // They tap "↻" until one is good, then send it.
        var shown: [String] = []
        for _ in 0..<3 {
            if let idea = suggestions.current { shown.append(idea.title) }
            suggestions.another()
        }
        print("DAY shown: \(shown)")
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: setup.profile, scriptLanguage: nil, interfaceLanguage: .english, preferredLanguages: ["en-US"]
        )
        for idea in shown.prefix(2) {
            let started = ContinuousClock.now
            let script = try await setup.writer.generate(factory.request(idea: idea, platform: .tiktok, format: nil))
            let seconds = started.duration(to: .now).inSeconds
            let text = CueParser.stripCues(script.text).lowercased()
            let ideaWords = IdeaFocus.words(in: idea, language: "en")
            let shared = ideaWords.filter { text.contains($0.prefix(5)) }
            print(String(
                format: "DAY script “%@”: %.0f s, %d words, shares %d of %d idea words · title “%@”",
                idea, seconds, words(script.text), shared.count, ideaWords.count, script.title
            ))
            #expect(seconds < 60, "“\(idea)” took \(Int(seconds)) s")
            #expect(Double(shared.count) >= Double(ideaWords.count) * 0.4, "The script is not about “\(idea)”: \(script.title)")
            #expect(!text.contains("[pause]... [pause]"))
        }
    }

    @Test func theToolsDoWhatTheySayToThatScript() async throws {
        let setup = try setup()
        defer { setup.defaults.tearDown() }
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: setup.profile, scriptLanguage: nil, interfaceLanguage: .english, preferredLanguages: ["en-US"]
        )
        let script = try await setup.writer.generate(factory.request(idea: "Why filling Italian forms takes me three tries", platform: .tiktok, format: nil))
        let before = words(script.text)
        print("DAY base: \(before) words")
        let context = RewriteContext(
            structure: .generic, platform: .tiktok, idealRange: 30...90, sourceLanguage: Locale.Language(identifier: "en"),
            voice: setup.profile.profile.voice(inLanguage: "en", idea: script.text)
        )
        var started = ContinuousClock.now
        let shorter = try await setup.writer.rewriteReported(script.text, with: .shorterAndDirect, context: context)
        print(String(
            format: "DAY shorter: %d → %d words in %.0f s (left %d of %d)",
            before, words(shorter.text), started.duration(to: .now).inSeconds, shorter.leftAsWritten, shorter.parts
        ))
        #expect(words(shorter.text) < before || before < 15)
        started = ContinuousClock.now
        let hooks = try await setup.writer.hooks(for: script.text, context: context)
        print(String(format: "DAY hooks: %d in %.0f s · %@", hooks.count, started.duration(to: .now).inSeconds, hooks.joined(separator: " | ")))
        #expect(hooks.count == 3 && Set(hooks).count == 3)
        started = ContinuousClock.now
        var spanish = context
        spanish.language = .spanish
        let translated = try await setup.writer.rewriteReported(script.text, with: .translate, context: spanish)
        print(String(format: "DAY translate: %d words in %.0f s", words(translated.text), started.duration(to: .now).inSeconds))
        #expect(OutputLanguageCheck.isPlausible(translated.text, in: .spanish))
        started = ContinuousClock.now
        var youtube = context
        youtube.platform = .youtube
        youtube.idealRange = TestData.rulesService().preset(for: .youtube, monetizationGoals: false).idealRange
        let version = try await setup.writer.rewriteReported(script.text, with: .fitToTime, context: youtube)
        let note = RewriteNotice.lengthNote(words: words(version.text), idealRange: youtube.idealRange)
        print(String(format: "DAY YouTube version: %d words in %.0f s · %@", words(version.text), started.duration(to: .now).inSeconds, note ?? "fits"))
        #expect(words(version.text) > before, "A version for YouTube is longer than a TikTok script")
    }
}
