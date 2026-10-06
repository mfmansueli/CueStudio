//
//  PrivacyPreferencesServiceTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Settings › Privacy & AI data: the switch that turns every Apple Intelligence feature off, and the usage switch.
@MainActor
@Suite("PrivacyPreferencesService")
struct PrivacyPreferencesServiceTests {
    @Test func aiIsOnAndUsageIsOffUntilTheCreatorChooses() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let writer = FakeScriptWriter()
        let privacy = PrivacyPreferencesService(defaults: store.defaults, writer: writer)
        #expect(privacy.usesOnDeviceAI)
        #expect(!privacy.helpsImproveCue)
        #expect(writer.isLanguageModelAvailable)
    }

    @Test func turningAIOffMakesTheWriterUnavailableWithTheReason() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let writer = FakeScriptWriter()
        let privacy = PrivacyPreferencesService(defaults: store.defaults, writer: writer)
        privacy.usesOnDeviceAI = false
        #expect(!writer.isLanguageModelAvailable)
        #expect(writer.writingUnavailableReason == AIAvailability.turnedOffReason)
        privacy.usesOnDeviceAI = true
        #expect(writer.isLanguageModelAvailable)
        #expect(writer.writingUnavailableReason == nil)
    }

    @Test func theChoicesAreRememberedAndAppliedToTheNextWriter() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let privacy = PrivacyPreferencesService(defaults: store.defaults, writer: FakeScriptWriter())
        privacy.usesOnDeviceAI = false
        privacy.helpsImproveCue = true
        let writer = FakeScriptWriter()
        let reloaded = PrivacyPreferencesService(defaults: store.defaults, writer: writer)
        #expect(!reloaded.usesOnDeviceAI)
        #expect(reloaded.helpsImproveCue)
        #expect(!writer.isEnabled)
    }
}
