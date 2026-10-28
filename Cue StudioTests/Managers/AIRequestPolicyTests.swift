//
//  AIRequestPolicyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Route-specific content requests")
struct AIRequestPolicyTests {
    private func request() -> ScriptRequest {
        var voice = QualityProfiles.english.full.voice(inLanguage: "en")
        voice.examples = [VoiceExample(text: "PRIVATE_PASTED_SAMPLE")]
        voice.approvedSamples = [VoiceExample(text: "PRIVATE_APPROVED_SAMPLE")]
        voice.excerpts = [VoiceExcerpt(text: "PRIVATE_IMPORTED_SAMPLE", language: "en")]
        voice.fingerprint = VoiceFingerprint(
            language: "en", pieces: 3, words: 500, wordsPerSentence: 12, questionShare: 0.1, exclamationShare: 0.01,
            emojiPer100Words: 0, averageWordLength: 5, singularWords: 20, pluralWords: 0, medianWords: 100, measuredAt: .now
        )
        return ScriptRequest(source: .prompt("Explain morning routines"), platform: .youtube, tone: nil, voice: voice,
                             targetRange: 240...300, language: .english)
    }

    @Test func cloudKeepsStyleWithoutSendingRawWritingSamples() {
        let original = request()
        let cloud = AIRequestPolicy.prepare(original, on: .privateCloud)
        let prompt = ScriptPromptBuilder.instructions(for: cloud)
        #expect(cloud.voice?.style == original.voice?.style)
        #expect(cloud.voice?.fingerprint == original.voice?.fingerprint)
        #expect(cloud.voice?.examples.isEmpty == true)
        #expect(cloud.voice?.approvedSamples.isEmpty == true)
        #expect(cloud.voice?.excerpts.isEmpty == true)
        #expect(!prompt.contains("PRIVATE_PASTED_SAMPLE") && !prompt.contains("PRIVATE_APPROVED_SAMPLE"))
        #expect(!prompt.contains("PRIVATE_IMPORTED_SAMPLE"))
        #expect(original.voice?.examples.isEmpty == false, "preparing the cloud must not erase the local library")
    }

    @Test func eachRouteIsPreparedFromTheOriginalAfterFallback() async {
        let original = request()
        let service = ScriptAIService(usesPrivateCloudCompute: false, measure: FakePromptMeasure(factor: 3))
        let local = await service.fitted(original, on: .onDevice)
        let cloud = await service.fitted(original, on: .privateCloud)
        let localAgain = await service.fitted(original, on: .onDevice)
        #expect(local.voiceBudget != nil)
        #expect(cloud.voice?.examples.isEmpty == true)
        #expect(localAgain.voice?.examples == original.voice?.examples)
        #expect(cloud.voiceBudget != local.voiceBudget)
    }

    @Test func longerCloudScriptsHaveRoomWithoutInflatingTheWordTarget() {
        let request = request()
        #expect(ScriptAIService.responseTokens(for: request, on: .privateCloud) > 1_800)
        #expect(ScriptAIService.responseTokens(for: request, on: .onDevice) <= 1_800)
        let cloud = ScriptPromptBuilder.askedRange(for: request.targetRange, on: .privateCloud)
        #expect(cloud.low == ReadTime.words(for: request.targetRange.lowerBound))
    }

    @Test func cloudCorrectionsCannotExceedTheirSharedRequestAllowance() throws {
        let budget = AIGenerationBudget(maximum: AIRequestPolicy.cloudScriptAttempts)
        try budget.consume()
        try budget.consume()
        #expect(throws: ScriptAIError.self) { try budget.consume() }
    }

    @Test func thePrivacySwitchStopsRequestsAtTheServiceBoundary() async throws {
        let service = ScriptAIService(usesPrivateCloudCompute: false, capabilities: FakeAIModelCapabilities())
        service.isEnabled = false
        do {
            _ = try await service.generate(request())
            Issue.record("A disabled writer must not generate a script")
        } catch let error as ScriptAIError {
            guard case .modelUnavailable(let reason) = error else {
                Issue.record("Expected the master-switch reason, got \(error)")
                return
            }
            #expect(reason == AIAvailability.turnedOffReason)
        }
    }

    @Test func aCloudTimeoutUsesTheAvailableDeviceInsteadOfRepeatingTheCloud() async throws {
        let service = ScriptAIService(usesPrivateCloudCompute: false)
        let plan = AIPlan(route: .privateCloud, usable: [.privateCloud, .onDevice])
        var routes: [AIModelRoute] = []
        let result = try await service.withFallback(plan) { route in
            routes.append(route)
            if route == .privateCloud { throw ScriptAIError.timedOut }
            return "recovered"
        }
        #expect(result == "recovered")
        #expect(routes == [.privateCloud, .onDevice])
    }
}
