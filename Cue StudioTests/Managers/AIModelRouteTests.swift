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

    @Test func onlyTheCloudHasAFallback() {
        #expect(AIModelRoute.privateCloud.fallback == .onDevice)
        #expect(AIModelRoute.onDevice.fallback == nil)
    }
}
