//
//  AIModelPlannerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Apple Intelligence being available says nothing about a language. The model for a request is
/// chosen from what the models write in the request's languages, and never from the languages Cue's
/// interface speaks.
@Suite("AIModelPlanner")
struct AIModelPlannerTests {
    private func plan(
        _ task: AIModelRoute.Task = .rewrite, _ languages: [String], on capabilities: FakeAIModelCapabilities = FakeAIModelCapabilities()
    ) async -> Result<AIPlan, AIPlanFailure> {
        await AIModelPlanner(capabilities: capabilities).plan(task, languages: languages.map(Locale.init(identifier:)))
    }

    @Test func aSupportedLanguageRunsOnTheDevice() async throws {
        let plan = try await plan(.rewrite, ["pt-BR"]).get()
        #expect(plan.route == .onDevice)
        #expect(plan.usable == [.onDevice])
    }

    /// Cue's Hindi, Indonesian, Arabic and Thai are not languages the device model writes.
    @Test(arguments: ["hi-IN", "id-ID", "ar-SA", "th-TH"])
    func aLanguageTheModelDoesntWriteIsNamedNotAttempted(_ identifier: String) async {
        let result = await plan(.rewrite, [identifier])
        guard case .failure(.unsupportedLanguage(let language)) = result else {
            Issue.record("Expected an unsupported language, got \(result)")
            return
        }
        #expect(language.languageCode == Locale(identifier: identifier).language.languageCode)
    }

    @Test func aTranslationNeedsBothLanguages() async {
        #expect(await plan(.rewrite, ["pt-BR", "de-DE"]).isSuccess)
        let result = await plan(.rewrite, ["pt-BR", "th-TH"])
        guard case .failure(.unsupportedLanguage(let language)) = result else {
            Issue.record("Expected the unsupported target, got \(result)")
            return
        }
        #expect(language.languageCode?.identifier == "th")
    }

    @Test func aDeviceThatCannotRunAppleIntelligenceSaysSoWhateverTheLanguage() async {
        let capabilities = FakeAIModelCapabilities(device: .deviceNotEligible, deviceLanguages: [])
        #expect(await plan(.rewrite, ["en-US"], on: capabilities).failure == .deviceNotSupported)
        #expect(await plan(.rewrite, ["th-TH"], on: capabilities).failure == .deviceNotSupported)
    }

    @Test func appleIntelligenceTurnedOffIsToldApart() async {
        let capabilities = FakeAIModelCapabilities(device: .turnedOff)
        #expect(await plan(.rewrite, ["en-US"], on: capabilities).failure == .turnedOff)
    }

    @Test func aModelStillPreparingIsToldApartFromALanguageItWontWrite() async {
        let preparing = FakeAIModelCapabilities(device: .preparing)
        #expect(await plan(.rewrite, ["en-US"], on: preparing).failure == .modelPreparing)
        // Waiting would not help a language it doesn't write.
        guard case .unsupportedLanguage? = await plan(.rewrite, ["th-TH"], on: preparing).failure else {
            Issue.record("A preparing model was blamed for a language it will never write")
            return
        }
    }

    // MARK: - Private Cloud Compute

    @Test func theCloudIsNeverAnOptionWhileItIsOff() async throws {
        let off = FakeAIModelCapabilities(cloud: nil, cloudLanguages: ["th"])
        // Thai is in the cloud's list, but the app doesn't offer the cloud: no entitlement, no request.
        #expect(await plan(.freePrompt, ["th-TH"], on: off).isSuccess == false)
        let plan = try await plan(.freePrompt, ["en-US"], on: off).get()
        #expect(plan.route == .onDevice)
        #expect(plan.usable == [.onDevice])
    }

    @Test func aLanguageOnlyTheCloudWritesGoesToTheCloudWhenItIsOffered() async throws {
        let both = FakeAIModelCapabilities(cloud: .available, cloudLanguages: ["th", "en"])
        let plan = try await plan(.rewrite, ["th-TH"], on: both).get()
        #expect(plan.route == .privateCloud)
        #expect(plan.usable == [.privateCloud])
    }

    @Test func aFallbackToAModelThatRefusesTheLanguageIsNeverPlanned() async throws {
        // The device writes English; the cloud (offered) doesn't list it: a failure on the device has nowhere to go.
        let capabilities = FakeAIModelCapabilities(cloud: .available, cloudLanguages: ["pt"])
        let plan = try await plan(.rewrite, ["en-US"], on: capabilities).get()
        #expect(plan.fallback(from: .onDevice, after: .tooLong) == nil)
        // Where both write it, the fallback is allowed.
        let both = FakeAIModelCapabilities(cloud: .available, cloudLanguages: ["en"])
        let shared = try await self.plan(.rewrite, ["en-US"], on: both).get()
        #expect(shared.fallback(from: .onDevice, after: .tooLong) == .privateCloud)
        #expect(shared.fallback(from: .onDevice, after: .other) == nil)
    }

    @Test func aUsedUpCloudQuotaIsNotAnOption() async throws {
        let capabilities = FakeAIModelCapabilities(cloud: .quotaReached, cloudLanguages: ["en"])
        let plan = try await plan(.freePrompt, ["en-US"], on: capabilities).get()
        #expect(plan.route == .onDevice)
    }

    // MARK: - Told at once

    @Test func theQuickCheckTellsWhatNeedsNoRequest() {
        let planner = AIModelPlanner(capabilities: FakeAIModelCapabilities())
        #expect(planner.quickFailure(languages: [Locale(identifier: "pt-BR")]) == nil)
        guard case .unsupportedLanguage? = planner.quickFailure(languages: [Locale(identifier: "ar-SA")]) else {
            Issue.record("Arabic should be refused at once")
            return
        }
    }

    @Test func theQuickCheckDoesNotRuleOutWhatTheCloudMayKnow() {
        let planner = AIModelPlanner(capabilities: FakeAIModelCapabilities(cloud: .available, cloudLanguages: ["ar"]))
        #expect(planner.quickFailure(languages: [Locale(identifier: "ar-SA")]) == nil)
    }
}

private extension Result {
    var isSuccess: Bool { if case .success = self { true } else { false } }
    var failure: Failure? { if case .failure(let failure) = self { failure } else { nil } }
}
