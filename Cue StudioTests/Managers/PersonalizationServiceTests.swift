//
//  PersonalizationServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Settings › Personalize: what is kept and what it starts as.
@MainActor
@Suite("PersonalizationService")
struct PersonalizationServiceTests {
    private func store() -> UserDefaults {
        let name = "studio.cue.tests.personalization.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func itStartsCalmWithEverythingOn() {
        let service = PersonalizationService(defaults: store())
        #expect(service.sky == .calm)
        #expect(service.celebrations && service.haptics && service.autoTagsTopics)
    }

    @Test func theChoicesAreKept() {
        let defaults = store()
        let service = PersonalizationService(defaults: defaults)
        service.sky = .lively
        service.celebrations = false
        service.haptics = false
        service.autoTagsTopics = false
        let again = PersonalizationService(defaults: defaults)
        #expect(again.sky == .lively)
        #expect(!again.celebrations && !again.haptics && !again.autoTagsTopics)
        Haptics.isEnabled = true
    }

    @Test func anUnknownSkyFallsBackToCalm() {
        let defaults = store()
        defaults.set("stormy", forKey: DefaultsKey.skyDensity)
        #expect(PersonalizationService(defaults: defaults).sky == .calm)
    }

    @Test func theHapticsSwitchReachesTheHapticsHelper() {
        let service = PersonalizationService(defaults: store())
        service.haptics = false
        #expect(!Haptics.isEnabled)
        service.haptics = true
        #expect(Haptics.isEnabled)
    }
}
