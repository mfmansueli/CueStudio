//
//  IdeaRelevanceDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// A creator types a few words into the dock's arrow and waits: does the script that comes back be about what they typed, and how long did it take?
/// The same idea is written through the service and the request factory the app uses, with no voice, with a voice and with an unrelated one, and
/// what is printed is what the creator would have seen: the seconds, the attempts, the title and the whole text. Opt-in, on a device with Apple
/// Intelligence, unlocked and awake: `CUE_DEVICE=<iPhone> scripts/test.sh device IdeaRelevanceDeviceTests`; `TEST_RUNNER_CUE_IDEA_TEXT` is the idea,
/// `…_CONDITIONS=none,founder` and `…_RUNS=3` pick what is run, and `…_VARIANT=v0…v3` the way of asking for the length (`LengthVariantsDeviceTests`).
@MainActor
@Suite("An idea becomes a script about that idea", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct IdeaRelevanceDeviceTests {
    nonisolated static let idea = ProcessInfo.processInfo.environment["CUE_IDEA_TEXT"] ?? "my daily routine with AI is not going so well"
    nonisolated static let conditions: [String] = {
        let all = ["none", "founder", "coach", "owner"]
        guard let named = ProcessInfo.processInfo.environment["CUE_CONDITIONS"], !named.isEmpty else { return all }
        return all.filter { named.split(separator: ",").map(String.init).contains($0) }
    }()
    /// The voice profile found on the owner's iPhone on 2026-10-07, without photo, name or handle: a custom role and topic "Daily Routine" with the
    /// detail "Bureaucracy", and "Languages" with "Italian".
    nonisolated static let ownerProfile = """
    {
     "style": {
      "energy": "balanced",
      "sentences": "mixed",
      "words": "plain",
      "swearing": "never"
     },
     "usesVoiceInAI": true,
     "excerpts": [],
     "customRole": "Daily Routine",
     "vocabulary": "genZ",
     "monetizationGoals": true,
     "voiceTopics": [
      "languages"
     ],
     "audienceGroup": "youngAdults",
     "defaultPlatform": "tiktok",
     "endings": [
      "Comment your answer"
     ],
     "unverifiedVoiceSteps": [],
     "contentGoals": [
      "grow",
      "raiseAwareness"
     ],
     "voiceApproved": true,
     "avoidNone": false,
     "approvals": 2,
     "topicDetails": {
      "Daily Routine": [
       "Bureaucracy"
      ],
      "languages": [
       "Italian"
      ]
     },
     "formats": [],
     "reach": {
      "platforms": [
       "tiktok",
       "reels",
       "stories",
       "shorts"
      ],
      "length": "oneToThree",
      "humor": "lot"
     },
     "avoid": [
      "Hype words",
      "Emojis in captions",
      "Politics"
     ],
     "phrases": [],
     "watchReasons": [
      "learn",
      "laugh"
     ],
     "examples": [],
     "approvedSamples": [],
     "audienceLevel": "some",
     "customTopics": [
      "Daily Routine"
     ],
     "customTags": [
      "Day in the life",
      "Talking head"
     ],
     "styles": [
      "shortSentences",
      "conversational"
     ],
     "declinedVoiceItems": [],
     "voiceSchemaVersion": 2,
     "niches": [],
     "sounds": [
      "casual",
      "funny"
     ],
     "confirmedVoiceSteps": [
      "audience",
      "tone"
     ],
     "openings": [
      "Story opener"
     ]
    }
    """
    nonisolated static let runs = Int(ProcessInfo.processInfo.environment["CUE_RUNS"] ?? "") ?? 1

    @Test(arguments: IdeaRelevanceDeviceTests.conditions)
    func theScriptIsAboutTheIdea(condition: String) async throws {
        KeepScreenAwake.enable()
        let service = ScriptAIService()
        guard service.availability.onDevice else { try Test.cancel("Apple Intelligence isn't available on this device") }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        // "app" asks as the app does; the others are the ways measured for the length (`LengthVariantsDeviceTests`), asked for every length.
        let variant = ProcessInfo.processInfo.environment["CUE_VARIANT"] ?? "app"
        let (factor, sentences, expands) = switch variant {
        case "v0": (1.0, false, false)
        case "v1": (1.5, false, false)
        case "v2": (1.5, true, false)
        case "v3": (1.5, true, true)
        default: (ScriptPromptBuilder.lengthAskFactor, ScriptPromptBuilder.asksSentencesPerBlock, ScriptAIService.expandsShortScripts)
        }
        let originals = (ScriptPromptBuilder.lengthAskFactor, ScriptPromptBuilder.asksSentencesPerBlock, ScriptAIService.expandsShortScripts)
        ScriptPromptBuilder.lengthAskFactor = factor
        ScriptPromptBuilder.asksSentencesPerBlock = sentences
        ScriptAIService.expandsShortScripts = expands
        defer {
            ScriptPromptBuilder.lengthAskFactor = originals.0
            ScriptPromptBuilder.asksSentencesPerBlock = originals.1
            ScriptAIService.expandsShortScripts = originals.2
        }
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profileService = CreatorProfileService(defaults: defaults.defaults)
        switch condition {
        case "founder": profileService.profile = try #require(VoicePersonas.persona("saas-founder")).profile
        case "coach": profileService.profile = try #require(VoicePersonas.persona("yoga-teacher")).profile
        case "owner": profileService.profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(Self.ownerProfile.utf8))
        default: break
        }
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: profileService, scriptLanguage: nil, interfaceLanguage: .english, preferredLanguages: ["en-US"]
        )
        for run in 0..<Self.runs {
            let request = factory.request(idea: Self.idea, platform: .tiktok, format: nil)
            if run == 0 {
                let sent = ScriptPromptBuilder.instructions(for: request) + "\n--- REQUEST ---\n" + ScriptPromptBuilder.prompt(for: request)
                print("IDEA \(condition) asked \(request.targetRange) s = \(ReadTime.words(for: request.targetRange.lowerBound))–\(ReadTime.words(for: request.targetRange.upperBound)) words")
                print("IDEA \(condition) PROMPT: \(sent.replacingOccurrences(of: "\n", with: " ⏎ "))")
            }
            let started = ContinuousClock.now
            do {
                let script = try await service.generate(request)
                let seconds = started.duration(to: .now).inSeconds
                let text = CueParser.stripCues(script.text).lowercased()
                let related = ["ai", "routine", "daily", "not going", "struggl", "tool", "chatgpt"].filter { text.contains($0) }
                print(String(
                    format: "IDEA %@ %@ #%d: %.0f s, %d words, attempts=%d expanded=%d model=%@ · related words: %@",
                    condition, variant, run, seconds, ReadTime.wordCount(in: script.text), script.attempts, script.expandedBlocks,
                    script.model.map { "\($0)" } ?? "none", related.joined(separator: ",")
                ))
                print("IDEA \(condition) \(variant) #\(run) TITLE: \(script.title)")
                print("IDEA \(condition) \(variant) #\(run) TEXT: \(script.text.replacingOccurrences(of: "\n", with: " ⏎ "))")
                #expect(related.count >= 2, "The script is not about the idea: \(script.title)")
                #expect(seconds < 90, "Took \(Int(seconds)) s")
            } catch {
                let took = Int(started.duration(to: .now).inSeconds)
                print("IDEA \(condition) \(variant) #\(run) FAILED after \(took) s: \(error) · \(ScriptAIService.lastEmptyReason ?? "")")
                Issue.record("\(error)")
            }
            try await Task.sleep(for: .seconds(4))
        }
    }
}
