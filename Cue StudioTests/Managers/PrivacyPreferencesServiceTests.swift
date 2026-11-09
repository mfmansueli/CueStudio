//
//  PrivacyPreferencesServiceTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// Settings › Privacy & AI data: the switch that turns every Apple Intelligence feature off, and "Help improve Cue", the one control of the usage
/// data and crash reports (owner, 09/11/2026).
@MainActor
@Suite("PrivacyPreferencesService")
struct PrivacyPreferencesServiceTests {
    @Test func aiIsOnAndUsageIsOffUntilTheCreatorChooses() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let writer = FakeScriptWriter()
        let privacy = PrivacyPreferencesService(defaults: store.defaults, writer: writer, telemetry: FakeTelemetry())
        #expect(privacy.usesOnDeviceAI)
        #expect(!privacy.helpsImproveCue)
        #expect(!PrivacyPreferencesService.helpsImprove(in: store.defaults), "what the launch reads before the services exist")
        #expect(writer.isLanguageModelAvailable)
    }

    @Test func turningAIOffMakesTheWriterUnavailable() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let writer = FakeScriptWriter()
        let privacy = PrivacyPreferencesService(defaults: store.defaults, writer: writer, telemetry: FakeTelemetry())
        privacy.usesOnDeviceAI = false
        #expect(!writer.isLanguageModelAvailable)
        privacy.usesOnDeviceAI = true
        #expect(writer.isLanguageModelAvailable)
    }

    @Test func theChoicesAreRememberedAndAppliedToTheNextWriter() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let privacy = PrivacyPreferencesService(defaults: store.defaults, writer: FakeScriptWriter(), telemetry: FakeTelemetry())
        privacy.usesOnDeviceAI = false
        privacy.helpsImproveCue = true
        let writer = FakeScriptWriter()
        let reloaded = PrivacyPreferencesService(defaults: store.defaults, writer: writer, telemetry: FakeTelemetry())
        #expect(!reloaded.usesOnDeviceAI)
        #expect(reloaded.helpsImproveCue)
        #expect(PrivacyPreferencesService.helpsImprove(in: store.defaults))
        #expect(!writer.isEnabled)
    }

    /// A fresh install collects nothing: the telemetry is told "off" as the service starts, and nothing is thrown away (there is nothing).
    @Test func aFreshInstallTellsTheTelemetryOff() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let telemetry = FakeTelemetry()
        _ = PrivacyPreferencesService(defaults: store.defaults, writer: FakeScriptWriter(), telemetry: telemetry)
        #expect(telemetry.calls == [.collecting(false)])
    }

    /// The choice made before reaches the telemetry at the next launch, so a creator who said yes keeps sending and one who didn't never does.
    @Test func theStoredChoiceIsAppliedAtLaunch() {
        let store = TestDefaults()
        defer { store.tearDown() }
        PrivacyPreferencesService(defaults: store.defaults, writer: FakeScriptWriter(), telemetry: FakeTelemetry()).helpsImproveCue = true
        let telemetry = FakeTelemetry()
        _ = PrivacyPreferencesService(defaults: store.defaults, writer: FakeScriptWriter(), telemetry: telemetry)
        #expect(telemetry.calls == [.collecting(true)])
    }

    /// Every change reaches the telemetry at once; turning it off also throws away what waits on this iPhone to be sent.
    @Test func everyChangeReachesTheTelemetryAndOffForgetsWhatWasWaiting() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let telemetry = FakeTelemetry()
        let privacy = PrivacyPreferencesService(defaults: store.defaults, writer: FakeScriptWriter(), telemetry: telemetry)
        privacy.helpsImproveCue = true
        #expect(telemetry.isCollecting == true)
        #expect(telemetry.discards == 0)
        privacy.helpsImproveCue = false
        #expect(telemetry.isCollecting == false)
        #expect(telemetry.calls.suffix(2) == [.collecting(false), .discardUnsent])
        // Off again (nothing changed): nothing more to throw away.
        privacy.helpsImproveCue = false
        #expect(telemetry.discards == 1)
    }

    /// Apple Intelligence's switch never touches the telemetry.
    @Test func theAISwitchLeavesTheTelemetryAlone() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let telemetry = FakeTelemetry()
        let privacy = PrivacyPreferencesService(defaults: store.defaults, writer: FakeScriptWriter(), telemetry: telemetry)
        privacy.usesOnDeviceAI = false
        privacy.usesOnDeviceAI = true
        #expect(telemetry.calls == [.collecting(false)])
    }
}
