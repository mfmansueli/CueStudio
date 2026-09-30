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

    @Test(arguments: [AIModelRoute.Task.format, .rewrite, .hooks, .themes])
    func everythingElseStaysOnTheDevice(_ task: AIModelRoute.Task) {
        #expect(AIModelRoute.choose(for: task, onDeviceAvailable: true, privateCloudAvailable: true) == .onDevice)
    }

    @Test func deviceTasksUseTheCloudWhenTheDeviceModelIsNotReady() {
        #expect(AIModelRoute.choose(for: .rewrite, onDeviceAvailable: false, privateCloudAvailable: true) == .privateCloud)
    }

    @Test func nothingRunsWithoutAppleIntelligence() {
        #expect(AIModelRoute.choose(for: .freePrompt, onDeviceAvailable: false, privateCloudAvailable: false) == nil)
    }

    @Test func anUnreachableCloudFallsBackToTheDevice() {
        #expect(AIModelRoute.privateCloud.fallback(after: .cloudUnreachable) == .onDevice)
    }

    @Test(arguments: [AIFailure.tooLong, .unsupportedLanguage])
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
