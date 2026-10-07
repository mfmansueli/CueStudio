//
//  LengthVariantsDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// Which way of asking the model for a length works best on a real iPhone: the same TikTok idea written several times with each way, counting how
/// often the model gives up (an answer that isn't a script), how many words it writes against the 150 asked for, and how long it takes. The ways:
/// `v0` the request as it was (the words asked as they are, "several complete sentences each", a whole second attempt when it is short); `v1` half
/// as many words again; `v2` half again and a count of sentences for every block; `v3` that and then the blocks lengthened or shortened one by one.
/// Opt-in on a device with Apple Intelligence, unlocked and awake:
/// `CUE_DEVICE=<iPhone> TEST_RUNNER_CUE_VARIANT=v1 scripts/test.sh device LengthVariantsDeviceTests`.
@MainActor
@Suite("Length variants on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct LengthVariantsDeviceTests {
    private static let runs = Int(ProcessInfo.processInfo.environment["CUE_RUNS"] ?? "") ?? 6

    @Test func writesTheSameIdeaSeveralTimes() async throws {
        KeepScreenAwake.enable()
        let service = ScriptAIService()
        guard service.availability.onDevice else { try Test.cancel("Apple Intelligence isn't available on this device") }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        let variant = ProcessInfo.processInfo.environment["CUE_VARIANT"] ?? "v3"
        let (factor, sentences, expands) = switch variant {
        case "v0": (1.0, false, false)
        case "v1": (1.5, false, false)
        case "v2": (1.5, true, false)
        default: (1.5, true, true)
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
        let persona = try #require(VoicePersonas.persona("saas-founder"))
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profileService = CreatorProfileService(defaults: defaults.defaults)
        profileService.profile = persona.profile
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: profileService, scriptLanguage: nil, interfaceLanguage: .english, preferredLanguages: ["en-US"]
        )
        var words: [Int] = []
        var failures = 0
        var seconds: [Double] = []
        for run in 0..<Self.runs {
            let request = factory.request(idea: persona.ideas[run % persona.ideas.count], platform: .tiktok, format: nil)
            let started = ContinuousClock.now
            do {
                let script = try await service.generate(request)
                let count = ReadTime.wordCount(in: CueParser.stripCues(script.text))
                words.append(count)
                seconds.append(started.duration(to: .now).inSeconds)
                let took = Int(seconds.last ?? 0)
                print("VARIANT \(variant) run \(run): \(count) words in \(took) s · attempts=\(script.attempts) expanded=\(script.expandedBlocks)")
            } catch {
                failures += 1
                print("VARIANT \(variant) run \(run): failed \(error) · \(ScriptAIService.lastEmptyReason ?? "")")
            }
            try await Task.sleep(for: .seconds(4))
        }
        let inRange = words.filter { $0 >= 105 && $0 <= 281 }.count
        let mean = words.isEmpty ? 0 : Double(words.reduce(0, +)) / Double(words.count)
        let time = seconds.isEmpty ? 0 : seconds.reduce(0, +) / Double(seconds.count)
        print(String(
            format: "VARIANT %@ SUMMARY runs=%d failed=%d in-range(105–281 words)=%d mean=%.0f words mean-time=%.0f s",
            variant, Self.runs, failures, inRange, mean, time
        ))
        #expect(Self.runs > 0)
    }
}
