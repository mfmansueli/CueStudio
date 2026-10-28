//
//  AILazyFallbackTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Local tasks defer cloud lookups")
struct AILazyFallbackTests {
    private actor Probe {
        var calls = 0
        func checked() { calls += 1 }
    }

    private struct Capabilities: AIModelCapabilities {
        let probe: Probe
        var deviceStatus: AIModelStatus { .available }
        var cloudStatus: AIModelStatus? { .available }
        func deviceSupports(_ locale: Locale) -> Bool { true }
        func cloudSupports(_ locale: Locale) async -> Bool {
            await probe.checked()
            return true
        }
    }

    @Test func ideasStartLocallyWithoutWaitingForCloudLanguages() async throws {
        let probe = Probe()
        let plan = try await AIModelPlanner(capabilities: Capabilities(probe: probe))
            .plan(.themes, languages: [Locale(identifier: "en")], checksFallback: false).get()
        #expect(plan.route == .onDevice)
        #expect(await probe.calls == 0)
        #expect(plan.usable == [.onDevice])
    }

    @Test func theCloudLanguageIsCheckedOnlyWhenTheLocalAttemptFails() async throws {
        let probe = Probe()
        let capabilities = Capabilities(probe: probe)
        let plan = try await AIModelPlanner(capabilities: capabilities)
            .plan(.themes, languages: [Locale(identifier: "en")], checksFallback: false).get()
        let service = ScriptAIService(usesPrivateCloudCompute: false, capabilities: capabilities)
        let result = try await service.withFallback(plan) { route in
            if route == .onDevice { throw ScriptAIError.timedOut }
            return route
        }
        #expect(result == .privateCloud)
        #expect(await probe.calls == 1)
    }
}
