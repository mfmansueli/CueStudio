//
//  IdeaLibraryDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// The developer tool that writes the idea library (`IdeaLibrary`), once: Ultra AI writes, natively in each of Cue's 20 languages, forty briefs for
/// each first-flight topic, two topics a call (20 calls a pair, about USD 0.10 each, counted in the lab's calls). Each idea is printed as a `LIBRARY` line (one
/// JSON) and each call's cost as `LIBRARYCOST`; `tools/ideas/collect_library.py` gathers the lines into `research_notes/Ideas/library-raw/`, and
/// `IdeaLibraryBuildTests` filters them into the bundle's packs. Synthetic: nothing of a creator is sent.
///
/// `CUE_DEVICE="iago Lima iphone" scripts/test.sh device IdeaLibraryDeviceTests` (`TEST_RUNNER_CUE_IDEA_LIBRARY=1`), the iPhone unlocked;
/// `TEST_RUNNER_CUE_IDEA_LIBRARY_LANGUAGES=pt,en` narrows it, `TEST_RUNNER_CUE_IDEA_LIBRARY_PAIRS=0,3` too (the topic pairs by number).
@MainActor
@Suite("Idea library by Ultra AI", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_IDEA_LIBRARY"] != nil))
struct IdeaLibraryDeviceTests {
    private nonisolated static func narrowed(_ name: String) -> Set<String>? {
        ProcessInfo.processInfo.environment[name].map { Set($0.split(separator: ",").map(String.init)) }
    }

    /// The ideas a topic gets.
    nonisolated static let perTopic = 40

    /// The first-flight topics, two a call: the ten it offered until 03/11/2026 (pairs 0–4, written 01/11), then the 24 broad themes added that
    /// day (pairs 5–16; `TEST_RUNNER_CUE_IDEA_LIBRARY_PAIRS=5,6,…,16` writes only those).
    nonisolated static let pairs: [[Niche]] = [
        [.fitness, .food], [.beauty, .fashion], [.finance, .tech], [.travel, .productivity], [.parenting, .lifestyle],
        [.business, .comedy], [.education, .healthcare], [.selfImprovement, .gaming], [.wellness, .musicArts], [.relationships, .sports],
        [.faith, .booksMovies], [.news, .homeDIY], [.shopping, .pets], [.realEstate, .artDesign], [.law, .cars], [.trades, .events],
        [.agriculture, .causes],
    ]

    /// Cue's interface languages (the String Catalog's), and how each is to be written.
    nonisolated static let languages: [(localization: String, name: String)] = [
        ("en", "English, natural for creators in the US, the UK, Canada and Australia (American spelling)"),
        ("pt", "Brazilian Portuguese, as Brazilian creators really talk on camera"),
        ("es", "Spanish, natural across Latin America and Spain (no regional slang)"),
        ("fr", "French"), ("de", "German"), ("it", "Italian"), ("nl", "Dutch"), ("da", "Danish"), ("sv", "Swedish"),
        ("nb", "Norwegian Bokmål"),
        ("ar", "Arabic, the Modern Standard register creators use on camera"),
        ("hi", "Hindi in Devanagari, the everyday register Indian creators use (English loanwords only where they really use them)"),
        ("id", "Indonesian"), ("ja", "Japanese"), ("ko", "Korean"), ("th", "Thai"), ("tr", "Turkish"), ("vi", "Vietnamese"),
        ("zh-Hans", "Simplified Chinese, as creators in mainland China write"),
        ("zh-Hant", "Traditional Chinese, as creators in Taiwan write"),
    ]

    nonisolated struct Case: Sendable, CustomTestStringConvertible {
        let localization: String
        let name: String
        let pair: Int
        var testDescription: String { "\(localization) · pair \(pair)" }
    }

    nonisolated static var cases: [Case] {
        let languages = narrowed("CUE_IDEA_LIBRARY_LANGUAGES")
        let pairs = narrowed("CUE_IDEA_LIBRARY_PAIRS")
        return Self.languages.flatMap { language in
            Self.pairs.indices.map { Case(localization: language.localization, name: language.name, pair: $0) }
        }
        .filter { languages?.contains($0.localization) ?? true }
        .filter { pairs?.contains(String($0.pair)) ?? true }
    }

    private struct Line: Encodable {
        let language: String
        let topic: String
        let angle: String
        let title: String
        let pointOfView: String
        let openingLine: String
    }

    static let instructions = """
        You are a senior short-form video strategist and a native writer of the language you are asked to write in. You write idea briefs for \
        creators who film themselves talking to the camera (TikTok, Instagram Reels, YouTube Shorts). You never translate from English: you write \
        the way creators who speak that language really title and open their videos.
        """

    static func prompt(language: String, topics: [Niche]) -> String {
        let angles = IdeaAngle.allCases.map { "\($0.rawValue) (\($0.ask))" }.joined(separator: "; ")
        let numbered = topics.enumerated().map { "\($0.offset + 1). \($0.element.promptName)" }.joined(separator: "\n")
        return """
            Write video ideas in \(language), for these topics:
            \(numbered)

            For each topic, write \(perTopic) ideas: two or three for each of these angles, every angle used: \(angles).

            Each idea:
            - topic: the topic's number.
            - angle: the angle's key, exactly as written above.
            - title: the video's title, at most 60 characters, naming its exact subject inside the topic (a sunscreen texture, a grocery \
            list, a resistance band), never a vague word alone ("products", "tips", "things").
            - pointOfView: one sentence, at most 20 words, telling the creator what to show, argue or explain: something the title doesn't \
            already say.
            - openingLine: the first sentence said on camera, at most 18 words, spoken and natural, without quotes, emojis or hashtags.

            Rules:
            - Anyone in the topic could film it. An idea is a draft the creator adjusts: an imagined scene in the first person is welcome \
            ("I used to…", "The day I…"), but never an invented number, study, statistic, credential or result presented as a fact.
            - Evergreen: no dates, years, seasons, holidays, trends, prices, currencies, brands, products by name, apps or celebrities.
            - Safe for every audience. Tips, never prescriptions: no medical, legal or financial promises, no diets or doses, no "guaranteed".
            - Every idea is a different subject from the others, not the same idea in other words; the titles vary in shape (not all \
            questions, not all numbers).
            - Everything in \(language), written as a native creator would say it.
            """
    }

    @Test(.timeLimit(.minutes(5)), arguments: Self.cases)
    func writeIdeas(_ item: Case) async throws {
        KeepScreenAwake.enable()
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        try #require(UltraLabConfiguration.isPresent, "Copy the lab's configuration into the app's Documents first")
        let client = try #require(FirebaseUltraClient.make(), "The lab's client couldn't be made")
        let budget = UltraCallBudget()
        try #require(budget.reserve(), "The lab's calls are used up (\(budget.used) of \(budget.limit))")
        let topics = Self.pairs[item.pair]
        let request = UltraStageRequest(stage: .ideas, instructions: Self.instructions, prompt: Self.prompt(language: item.name, topics: topics))
        let started = ContinuousClock.now
        let reply = try await client.generate(request) { _ in }
        let seconds = started.duration(to: .now).inSeconds
        var cost = UltraCost()
        cost.add(reply)
        print(String(
            format: "LIBRARYCOST %@ pair %d: %.0f s, in %d, out %d, thinking %d, USD %.4f, finished %@", item.localization, item.pair, seconds,
            reply.promptTokens ?? 0, reply.outputTokens ?? 0, reply.thinkingTokens ?? 0, cost.dollars(), reply.finishedNormally ? "yes" : "no"
        ))
        let text = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsed = try JSONDecoder().decode(IdeaLibraryReply.self, from: Data(text.utf8))
        var counts: [String: Int] = [:]
        for idea in parsed.ideas {
            guard topics.indices.contains(idea.topic - 1) else { continue }
            let niche = topics[idea.topic - 1]
            counts[niche.rawValue, default: 0] += 1
            let line = Line(
                language: item.localization, topic: niche.rawValue, angle: idea.angle, title: idea.title, pointOfView: idea.pointOfView,
                openingLine: idea.openingLine
            )
            if let data = try? JSONEncoder().encode(line), let json = String(data: data, encoding: .utf8) { print("LIBRARY \(json)") }
        }
        Attachment.record(Data(text.utf8), named: "idea-library-\(item.localization)-\(item.pair).json")
        for niche in topics {
            #expect((counts[niche.rawValue] ?? 0) >= Self.perTopic * 3 / 4, "\(niche.rawValue): \(counts[niche.rawValue] ?? 0) ideas")
        }
    }
}

/// What a library call answers (`UltraStageRequest.Stage.ideas`).
private nonisolated struct IdeaLibraryReply: Decodable {
    let ideas: [IdeaLibraryReplyIdea]
}

private nonisolated struct IdeaLibraryReplyIdea: Decodable {
    let topic: Int
    let angle: String
    let title: String
    let pointOfView: String
    let openingLine: String
}
