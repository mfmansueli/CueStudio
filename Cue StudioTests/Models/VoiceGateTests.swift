//
//  VoiceGateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Any answer the brief can tell the model turns the voice on, not only the Essentials: a creator who only said how they end, or only pasted
/// examples, is written for in their voice. Each route then sends what its policy takes, and the switch off sends nothing
/// (`reports/entradas-do-criador-2026-11-01-completo.md` §11, A5).
@MainActor
struct VoiceGateTests {
    private func factory(_ profile: CreatorProfile) -> (ScriptRequestFactory, CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.profile = profile
        let factory = ScriptRequestFactory(rules: TestData.rulesService(), profile: service, scriptLanguage: nil, interfaceLanguage: .english)
        return (factory, service, defaults)
    }

    private func instructions(_ request: ScriptRequest, on route: AIModelRoute) -> String {
        ScriptPromptBuilder.instructions(for: AIRequestPolicy.prepare(request, on: route))
    }

    @Test func aNewProfileStillHasNothingToSend() {
        #expect(!CreatorProfile().canWriteInMyVoice, "defaults a new profile starts with are not answers")
    }

    @Test func onlyAnEndingIsSentOnBothRoutes() {
        var profile = CreatorProfile()
        profile.endings = ["See you Sunday"]
        let (factory, service, defaults) = factory(profile)
        defer { defaults.tearDown() }
        #expect(service.writesInMyVoice)
        let request = factory.request(idea: "My Sunday reset routine", platform: .tiktok, format: nil)
        #expect(instructions(request, on: .onDevice).contains("See you Sunday"))
        #expect(instructions(request, on: .privateCloud).contains("See you Sunday"))
    }

    @Test func onlyExamplesGoOnTheIPhoneAndNothingGoesToPrivateCloudCompute() {
        var profile = CreatorProfile()
        profile.examples = [VoiceExample(text: "Okay, real talk: bread is patience you can eat, and your starter is not dead, it is sleeping.")]
        let (factory, service, defaults) = factory(profile)
        defer { defaults.tearDown() }
        #expect(service.writesInMyVoice)
        let request = factory.request(idea: "Why my sourdough starter isn't dead", platform: .tiktok, format: nil)
        #expect(instructions(request, on: .onDevice).contains("your starter is not dead"))
        let cloud = instructions(request, on: .privateCloud)
        #expect(!cloud.contains("your starter is not dead") && !cloud.contains("Write in the creator's own voice"), "\(cloud)")
    }

    @Test func theSwitchOffSendsNothing() {
        var profile = CreatorProfile()
        profile.endings = ["See you Sunday"]
        profile.usesVoiceInAI = false
        let (factory, service, defaults) = factory(profile)
        defer { defaults.tearDown() }
        #expect(!service.writesInMyVoice)
        let request = factory.request(idea: "My Sunday reset routine", platform: .tiktok, format: nil)
        #expect(request.voice == nil)
        #expect(!instructions(request, on: .onDevice).contains("See you Sunday"))
    }
}
