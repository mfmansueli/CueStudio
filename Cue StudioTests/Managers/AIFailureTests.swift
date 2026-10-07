//
//  AIFailureTests.swift
//  Cue StudioTests
//

import Foundation
import FoundationModels
import Testing
@testable import Cue_Studio

@Suite("AIFailure")
struct AIFailureTests {
    @Test func privateCloudComputeErrorsMeanTheCloudIsOutOfReach() {
        let offline = PrivateCloudComputeLanguageModel.Error.networkFailure(.init(debugDescription: "offline"))
        let quota = PrivateCloudComputeLanguageModel.Error.quotaLimitReached(.init(debugDescription: "quota"))
        let down = PrivateCloudComputeLanguageModel.Error.serviceUnavailable(.init(debugDescription: "down"))
        #expect(AIFailure(offline) == .cloudUnreachable)
        #expect(AIFailure(quota) == .cloudUnreachable)
        #expect(AIFailure(down) == .cloudUnreachable)
    }

    @Test func aFullContextIsTooLong() {
        let error = LanguageModelError.contextSizeExceeded(.init(contextSize: 4096, tokenCount: 5200, debugDescription: "full"))
        #expect(AIFailure(error) == .tooLong)
    }

    @Test func aMissingLanguageIsUnsupported() {
        let error = LanguageModelError.unsupportedLanguageOrLocale(.init(languageCode: "th", debugDescription: "th"))
        #expect(AIFailure(error) == .unsupportedLanguage)
    }

    @Test func modelFilesThatAreNotReadyMeanThePreparingModel() {
        let error = SystemLanguageModel.Error.assetsUnavailable(.init(debugDescription: "downloading"))
        #expect(AIFailure(error) == .modelPreparing)
    }

    /// A rest is what a rate limited model needs: no retry, no other model.
    @Test func aRateLimitAsksForARest() {
        let error = LanguageModelError.rateLimited(.init(resetDate: nil, debugDescription: "limited"))
        #expect(AIFailure(error) == .rateLimited)
        #expect(AIModelRoute.onDevice.fallback(after: .rateLimited) == nil)
        #expect(AIModelRoute.privateCloud.fallback(after: .rateLimited) == nil)
        #expect(ScriptAIError.rateLimited.explainsItself)
    }

    /// Stopping a request is not a failure to explain or to try elsewhere.
    @Test func aCancellationIsNotAFailure() {
        #expect(AIFailure(CancellationError()) == .cancelled)
        #expect(AIModelRoute.onDevice.fallback(after: .cancelled) == nil)
        #expect(AIModelRoute.privateCloud.fallback(after: .cancelled) == nil)
    }

    @Test func anythingElseIsNotRetried() {
        #expect(AIFailure(LanguageModelError.timeout(.init(debugDescription: "slow"))) == .other)
        #expect(AIFailure(ScriptAIError.emptyResponse) == .other)
    }

    /// Measured on an iPhone 15 Pro: "May contain unsafe content" over a script about cold showers. Another model wouldn't do better, and the creator is
    /// told in Cue's words.
    @Test func aRefusalIsDeclinedAndExplained() {
        #expect(AIFailure(LanguageModelError.refusal(.init(explanation: "no", debugDescription: "no"))) == .declined)
        #expect(AIFailure(LanguageModelError.guardrailViolation(.init(debugDescription: "unsafe"))) == .declined)
        #expect(AIModelRoute.onDevice.fallback(after: .declined) == nil)
        #expect(ScriptAIError.declined.explainsItself)
        #expect(ScriptAIError.declined.localizedDescription.contains("rewording"))
    }
}
