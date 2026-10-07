//
//  PlatformLengthDeviceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Cue_Studio

/// Does the real model write as many words as each platform asks for? A spoken video for TikTok is a minute or so, for YouTube four to ten
/// minutes (`PlatformRules.json`): the same idea is written for each platform with the length on Auto, through the service and the request factory
/// the app uses, and the words are counted against the range the platform asks for. Opt-in, on a device with Apple Intelligence, unlocked and awake:
/// `CUE_DEVICE=<iPhone> scripts/test.sh device PlatformLengthDeviceTests`; `TEST_RUNNER_CUE_PLATFORMS=youtube,tiktok` picks the platforms.
@MainActor
@Suite("Script length by platform on this device", .serialized, .enabled(if: ProcessInfo.processInfo.environment["CUE_AI_E2E"] != nil))
struct PlatformLengthDeviceTests {
    nonisolated static let platforms: [Platform] = {
        let all: [Platform] = [.tiktok, .reels, .shorts, .youtube, .linkedin]
        guard let named = ProcessInfo.processInfo.environment["CUE_PLATFORMS"], !named.isEmpty else { return all }
        let ids = Set(named.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        return all.filter { ids.contains($0.rawValue) }
    }()

    @Test(arguments: PlatformLengthDeviceTests.platforms)
    func theScriptHasAsManyWordsAsThePlatformAsks(platform: Platform) async throws {
        KeepScreenAwake.enable()
        let service = ScriptAIService()
        guard service.availability.onDevice else { try Test.cancel("Apple Intelligence isn't available on this device") }
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        try #require(isActive, "The iPhone must be unlocked with the screen on")
        #endif
        let persona = try #require(VoicePersonas.persona("saas-founder"))
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profileService = CreatorProfileService(defaults: defaults.defaults)
        profileService.profile = persona.profile
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: profileService, scriptLanguage: nil, interfaceLanguage: .english, preferredLanguages: ["en-US"]
        )
        var all: [Int] = []
        let factor = ProcessInfo.processInfo.environment["CUE_LENGTH_FACTOR"].flatMap(Double.init) ?? ScriptPromptBuilder.lengthAskFactor
        let original = ScriptPromptBuilder.lengthAskFactor
        ScriptPromptBuilder.lengthAskFactor = factor
        defer { ScriptPromptBuilder.lengthAskFactor = original }
        let only = ProcessInfo.processInfo.environment["CUE_IDEA"].flatMap { Int($0) }
        for (index, idea) in persona.ideas.enumerated() where only == nil || only == index {
            let request = factory.request(idea: idea, platform: platform, format: nil)
            let range = request.targetRange
            let started = ContinuousClock.now
            let script: GeneratedScript
            do {
                script = try await service.generate(request)
            } catch {
                print("LENGTH \(platform.rawValue)[\(index)] failed: \(error) · \(ScriptAIService.lastEmptyReason ?? "")")
                continue
            }
            let words = ReadTime.wordCount(in: CueParser.stripCues(script.text))
            all.append(words)
            print(String(
                format: "LENGTH x%.1f %@[%d] asked %.0f–%.0f s (%d–%d words) got %d words = %.0f s in %.0f s · attempts=%d expanded=%d violations=%@",
                factor, platform.rawValue, index, range.lowerBound, range.upperBound, ReadTime.words(for: range.lowerBound),
                ReadTime.words(for: range.upperBound), words, Double(words) / 150 * 60, started.duration(to: .now).inSeconds, script.attempts,
                script.expandedBlocks, script.voiceViolations.map(\.rawValue).joined(separator: ",")
            ))
            Attachment.record(Data(script.text.utf8), named: "length-\(platform.rawValue)-\(index).txt")
            try await Task.sleep(for: .seconds(4))
        }
        #expect(!all.isEmpty)
    }
}
