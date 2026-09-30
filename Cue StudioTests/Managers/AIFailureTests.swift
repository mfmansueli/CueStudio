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

    @Test func anythingElseIsNotRetried() {
        #expect(AIFailure(LanguageModelError.timeout(.init(debugDescription: "slow"))) == .other)
        #expect(AIFailure(ScriptAIError.emptyResponse) == .other)
        #expect(AIFailure(CancellationError()) == .other)
    }
}
