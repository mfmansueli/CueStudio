//
//  AIModelRouteTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("AIModelRoute")
struct AIModelRouteTests {
    @Test func freePromptsGoToPrivateCloudCompute() {
        #expect(AIModelRoute.choose(for: .freePrompt, onDeviceAvailable: true, privateCloudAvailable: true) == .privateCloud)
    }

    @Test func freePromptsFallBackToTheDevice() {
        #expect(AIModelRoute.choose(for: .freePrompt, onDeviceAvailable: true, privateCloudAvailable: false) == .onDevice)
    }

    /// The touch-ups go to Private Cloud Compute first: on the iPhone it kept each tool's promise 86 times in 113 against the device's 58.
    @Test(arguments: [AIModelRoute.Task.rewrite, .hooks])
    func touchUpsGoToPrivateCloudCompute(_ task: AIModelRoute.Task) {
        #expect(AIModelRoute.choose(for: task, onDeviceAvailable: true, privateCloudAvailable: true) == .privateCloud)
        #expect(AIModelRoute.choose(for: task, onDeviceAvailable: true, privateCloudAvailable: false) == .onDevice)
    }

    @Test(arguments: [AIModelRoute.Task.format, .themes])
    func theDraftAndIdeasStayOnTheDevice(_ task: AIModelRoute.Task) {
        #expect(AIModelRoute.choose(for: task, onDeviceAvailable: true, privateCloudAvailable: true) == .onDevice)
    }

    @Test func deviceTasksUseTheCloudWhenTheDeviceModelIsNotReady() {
        #expect(AIModelRoute.choose(for: .themes, onDeviceAvailable: false, privateCloudAvailable: true) == .privateCloud)
    }

    /// What the cloud refuses, the device (with the guardrails made for the creator's own words) may take.
    @Test func whatTheCloudRefusesIsTriedOnTheDevice() {
        #expect(AIModelRoute.privateCloud.fallback(after: .declined) == .onDevice)
        #expect(AIModelRoute.onDevice.fallback(after: .declined) == nil)
    }

    @Test func nothingRunsWithoutAppleIntelligence() {
        #expect(AIModelRoute.choose(for: .freePrompt, onDeviceAvailable: false, privateCloudAvailable: false) == nil)
    }

    @Test func anUnreachableCloudFallsBackToTheDevice() {
        #expect(AIModelRoute.privateCloud.fallback(after: .cloudUnreachable) == .onDevice)
    }

    @Test(arguments: [AIFailure.tooLong, .unsupportedLanguage, .modelPreparing])
    func whatDoesNotFitTheDeviceGoesToTheCloud(_ failure: AIFailure) {
        #expect(AIModelRoute.onDevice.fallback(after: failure) == .privateCloud)
    }

    @Test func theCloudDoesNotRetryWhatItCouldNotFit() {
        #expect(AIModelRoute.privateCloud.fallback(after: .tooLong) == nil)
        #expect(AIModelRoute.privateCloud.fallback(after: .unsupportedLanguage) == nil)
    }

    @Test(arguments: [AIModelRoute.onDevice, .privateCloud])
    func otherFailuresAreNotRetried(_ route: AIModelRoute) {
        #expect(route.fallback(after: .other) == nil)
    }
}
