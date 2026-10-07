//
//  ScriptToolsDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// Does each tool of "Improve script" do what its name says? Every tool runs on a real iPhone, on a script made for it, and what came back is
/// measured against the promise: "Shorter & direct" has fewer words, "Fit to time" lands in the platform's length, "Fix grammar" fixes the
/// mistakes and nothing else, "Stronger CTA" changes the closing paragraph and only that, "Translate" is in the language asked, "3 new hooks" gives
/// three different openings. A tool whose result doesn't keep its promise is a bug the creator would see as a button that lies. Opt-in on a device
/// with Apple Intelligence, unlocked and awake: `CUE_DEVICE=<iPhone> scripts/test.sh device ScriptToolsDeviceTests`.
@MainActor
@Suite("Script tools keep their promises on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct ScriptToolsDeviceTests {
    // MARK: - The scripts

    /// About 120 words, with filler and repetition to cut.
    static let wordy = """
    [look at camera] So, um, basically what I want to tell you today is that I have been, like, trying a new morning routine for about a month now, \
    and honestly, it has really, really changed how my days feel.

    So the first thing I do, the very first thing, is I drink a big glass of water before I even look at my phone, because, you know, your phone \
    can wait. Then I stretch for, like, five minutes, just five minutes, nothing crazy. And then I write down the three things that matter most \
    today, and honestly that is the whole thing, that is basically all of it.

    [pause] If you want to try it, you can try it tomorrow, and if you do, tell me in the comments how it went for you, okay?
    """

    /// Mistakes of spelling, grammar and punctuation, in about 60 words.
    static let mistakes = """
    i dont know why but my mornings was always a mess. Their going to say its easy, but it taked me three weeks to get it rite. \
    Me and my sister started wake up at six, and we feels much more better now. Alot of people thinks you needs a lot of time, you dont.
    """

    /// A sponsored read with an apology that takes itself back, and a weak close.
    static let defensive = """
    I'm sorry, but I know this video is a bit long, and I really didn't have a choice, it's not my fault the topic is big.

    Here is what I learned from three months of testing this planner: it helps me finish my week with less stress, and it is simple to use.

    So yeah, if you want, maybe check it out, I guess.
    """

    /// 35 words, to be stretched to the platform's length.
    static let brief = """
    I tried cold showers for thirty days. The first week was awful. By week three I stopped dreading them, and my mornings felt calmer. \
    Here is what I would tell my past self before starting.
    """

    static let platformRange: ClosedRange<TimeInterval> = 60...90

    // MARK: - Setup

    private func service() throws -> ScriptAIService {
        KeepScreenAwake.enable()
        let service = ScriptAIService()
        guard service.availability.onDevice else { try Test.cancel("Apple Intelligence isn't available on this device") }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        return service
    }

    private func context(language: Locale.Language = Locale.Language(identifier: "en"), target: CueLanguage? = nil) -> RewriteContext {
        RewriteContext(
            structure: .generic, platform: .tiktok, idealRange: Self.platformRange, language: target, sourceLanguage: language, voice: nil
        )
    }

    private func words(_ text: String) -> Int { ReadTime.wordCount(in: CueParser.stripCues(text)) }

    private func paragraphs(_ text: String) -> [String] { CueParser.paragraphs(in: text) }

    private func report(_ tool: String, _ before: String, _ after: String, _ note: String = "") {
        print("TOOL \(tool): \(words(before)) → \(words(after)) words \(note) · “\(after.prefix(110).replacingOccurrences(of: "\n", with: " "))”")
    }

    // MARK: - The promises

    @Test func shorterAndDirectHasFewerWords() async throws {
        let service = try service()
        var results: [Double] = []
        for _ in 0..<3 {
            let after = try await service.rewrite(Self.wordy, with: .shorterAndDirect, context: context())
            report("shorterAndDirect", Self.wordy, after)
            results.append(Double(words(after)) / Double(words(Self.wordy)))
            try await Task.sleep(for: .seconds(3))
        }
        print("TOOL shorterAndDirect SUMMARY ratios \(results.map { String(format: "%.2f", $0) })")
        #expect(results.allSatisfy { $0 < 0.9 }, "It said shorter but kept most of the words: \(results)")
    }

    @Test func fitToTimeStretchesAShortScript() async throws {
        let service = try service()
        let after = try await service.rewrite(Self.brief, with: .fitToTime, context: context())
        let low = ReadTime.words(for: Self.platformRange.lowerBound)
        let high = ReadTime.words(for: Self.platformRange.upperBound)
        report("fitToTime (short)", Self.brief, after, "asked \(low)–\(high)")
        let count = words(after)
        #expect(count >= Int(Double(low) * 0.8), "Fit to time left \(count) words, asked \(low)–\(high)")
        #expect(count <= Int(Double(high) * 1.2))
    }

    @Test func fitToTimeTrimsALongScript() async throws {
        let service = try service()
        let long = (0..<4).map { _ in Self.wordy }.joined(separator: "\n\n")
        let after = try await service.rewrite(long, with: .fitToTime, context: context())
        let low = ReadTime.words(for: Self.platformRange.lowerBound)
        let high = ReadTime.words(for: Self.platformRange.upperBound)
        report("fitToTime (long)", long, after, "asked \(low)–\(high)")
        let count = words(after)
        #expect(count >= Int(Double(low) * 0.8), "Fit to time left \(count) words, asked \(low)–\(high)")
        #expect(count <= Int(Double(high) * 1.2), "Fit to time left \(count) words, asked \(low)–\(high)")
    }

    @Test func fixGrammarFixesAndOnlyThat() async throws {
        let service = try service()
        let after = try await service.rewrite(Self.mistakes, with: .fixGrammar, context: context())
        report("fixGrammar", Self.mistakes, after)
        let lower = after.lowercased()
        #expect(!lower.contains("dont"), "“dont” is still there")
        #expect(!lower.contains("taked") && !lower.contains(" rite"), "A misspelling is still there")
        #expect(after.hasPrefix("I "), "The lone “i” is still lowercase")
        let ratio = Double(words(after)) / Double(words(Self.mistakes))
        #expect(ratio > 0.85 && ratio < 1.15, "Fix grammar rewrote it instead of fixing it (\(ratio)× the words)")
    }

    @Test func fixGrammarLeavesACleanScriptAlone() async throws {
        let service = try service()
        let clean = "I tried cold showers for thirty days. The first week was awful, but by week three I stopped dreading them."
        let after = try await service.rewrite(clean, with: .fixGrammar, context: context())
        report("fixGrammar (clean)", clean, after)
        let ratio = Double(words(after)) / Double(words(clean))
        #expect(ratio > 0.9 && ratio < 1.1, "A script with nothing wrong changed by \(ratio)×")
    }

    @Test func strongerCTAChangesTheClosingAndOnlyThat() async throws {
        let service = try service()
        let before = paragraphs(Self.defensive)
        let after = try await service.rewrite(Self.defensive, with: .strongerCTA, context: context())
        report("strongerCTA", Self.defensive, after)
        let now = paragraphs(after)
        #expect(now.count >= 2)
        #expect(now.last != before.last, "The closing paragraph is the same")
        #expect(Array(now.dropLast()).joined() == Array(before.dropLast()).joined(), "Stronger CTA touched what comes before the closing")
        #expect(!(now.last ?? "").lowercased().contains("i guess"), "The close still hedges")
    }

    @Test func lessDefensiveTakesTheExcusesOut() async throws {
        let service = try service()
        let after = try await service.rewrite(Self.defensive, with: .lessDefensive, context: context())
        report("lessDefensive", Self.defensive, after)
        let lower = after.lowercased()
        #expect(!lower.contains("sorry, but"), "The apology that takes itself back is still there")
        #expect(!lower.contains("not my fault") && !lower.contains("didn't have a choice"), "An excuse is still there")
        #expect(lower.contains("planner"), "The substance is gone")
    }

    @Test func moreEnergyIsPunchier() async throws {
        let service = try service()
        let calm = "Today I want to talk about my morning routine. It is a simple routine. I wake up and I drink water. Then I stretch and I write down what matters."
        let after = try await service.rewrite(calm, with: .moreEnergy, context: context())
        report("moreEnergy", calm, after)
        let sentences = WritingText.sentences(in: after, language: "en")
        let average = Double(words(after)) / Double(max(1, sentences.count))
        let before = Double(words(calm)) / Double(max(1, WritingText.sentences(in: calm, language: "en").count))
        let exclamations = after.filter { $0 == "!" }.count
        print("TOOL moreEnergy: words per sentence \(String(format: "%.1f", before)) → \(String(format: "%.1f", average)), \(exclamations) exclamations")
        #expect(after != calm)
        #expect(average < before || exclamations > 0, "It is neither shorter in sentences nor louder")
    }

    @Test func moreHumanDropsTheCorporateWords() async throws {
        let service = try service()
        let stiff = "We are pleased to leverage synergies to utilize our learnings and deliver actionable value to all stakeholders going forward."
        let after = try await service.rewrite(stiff, with: .moreHuman, context: context())
        report("moreHuman", stiff, after)
        let lower = after.lowercased()
        let left = ["leverage", "synerg", "utilize", "stakeholder", "actionable"].filter { lower.contains($0) }
        #expect(left.count <= 1, "Still sounds corporate: \(left)")
    }

    @Test func inMyVoiceChangesTheWordsAndKeepsThePoints() async throws {
        let service = try service()
        let persona = try #require(VoicePersonas.persona("saas-founder"))
        let voice = persona.profile.voice(inLanguage: "en", idea: Self.wordy)
        var context = context()
        context.voice = voice
        let after = try await service.rewrite(Self.wordy, with: .inMyVoice, context: context)
        report("inMyVoice", Self.wordy, after)
        #expect(after != Self.wordy)
        let ratio = Double(words(after)) / Double(words(Self.wordy))
        #expect(ratio > 0.4 && ratio < 1.5, "“Keep every point and the same length” came back \(ratio)× long")
        #expect(after.lowercased().contains("water"), "A point of the script is gone")
    }

    @Test(arguments: [CueLanguage.spanish, .portugueseBrazil, .french, .german])
    func translateIsInTheLanguageAsked(target: CueLanguage) async throws {
        let service = try service()
        let after = try await service.rewrite(Self.wordy, with: .translate, context: context(target: target))
        report("translate→\(target.rawValue)", Self.wordy, after)
        #expect(OutputLanguageCheck.isPlausible(after, in: target), "Not in \(target.rawValue): \(after.prefix(100))")
        #expect(after.contains("[pause]") || after.contains("[look at camera]") || after.contains("["), "The stage cues were dropped")
    }

    @Test func threeNewHooksAreThreeDifferentOpenings() async throws {
        let service = try service()
        let hooks = try await service.hooks(for: Self.wordy, context: context())
        print("TOOL hooks: \(hooks)")
        #expect(hooks.count == 3)
        #expect(Set(hooks.map { $0.lowercased() }).count == 3, "Two hooks are the same")
        #expect(hooks.allSatisfy { !$0.isEmpty && words($0) <= 30 }, "A hook is empty or is not a hook")
        let opening = ScriptTextEditing.opening(of: Self.wordy)
        #expect(!hooks.contains(opening), "A hook is the opening it was meant to replace")
    }

    // MARK: - Scripts of every length

    /// A YouTube video is eight minutes and more: the tools can't answer "too long" to the length the platform asks for. Each size runs "Fix grammar"
    /// (which must keep the length) and reports whether it came back, in how long and with how many words.
    @Test(arguments: [300, 600, 900, 1200, 1600])
    func aLongScriptIsStillWorkedOn(words wanted: Int) async throws {
        let service = try service()
        let paragraph = Self.mistakes + "\n\n" + Self.wordy
        var text = paragraph
        while words(text) < wanted { text += "\n\n" + paragraph }
        let started = ContinuousClock.now
        do {
            let after = try await service.rewrite(text, with: .fixGrammar, context: context())
            let took = Int(started.duration(to: .now).inSeconds)
            print("TOOL long fixGrammar \(words(text)) words: came back with \(words(after)) words in \(took) s")
            let ratio = Double(words(after)) / Double(words(text))
            #expect(ratio > 0.8, "Fix grammar on \(words(text)) words kept only \(words(after))")
        } catch {
            print("TOOL long fixGrammar \(words(text)) words: FAILED \(error)")
            Issue.record("A script of \(words(text)) words can't be worked on: \(error)")
        }
    }

    /// "Make a version for YouTube": a short script made as long as the platform asks, and a long one cut to a short platform's.
    @Test(arguments: [Platform.tiktok, .youtube, .linkedin])
    func aVersionForAPlatformHasThePlatformsLength(platform: Platform) async throws {
        let service = try service()
        let rules = TestData.rulesService()
        let range = rules.preset(for: platform, monetizationGoals: false).idealRange
        var ctx = context()
        ctx.platform = platform
        ctx.idealRange = range
        let low = ReadTime.words(for: range.lowerBound)
        let high = ReadTime.words(for: range.upperBound)
        let after = try await service.rewrite(Self.wordy, with: .fitToTime, context: ctx)
        print("TOOL version \(platform.rawValue): \(words(Self.wordy)) → \(words(after)) words, asked \(low)–\(high)")
        #expect(words(after) >= Int(Double(low) * 0.7), "The \(platform.rawValue) version has \(words(after)) words, asked \(low)–\(high)")
        #expect(words(after) <= Int(Double(high) * 1.3))
    }
}
