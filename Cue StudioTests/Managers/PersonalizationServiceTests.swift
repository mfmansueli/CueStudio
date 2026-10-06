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

    @Test func itStartsWithTheCalmSkyAndEverythingOn() {
        let service = PersonalizationService(defaults: store())
        #expect(service.sky == .calm)
        #expect(service.celebrations && service.haptics && service.autoTagsTopics)
    }

    @Test func theChoicesAreKept() {
        let defaults = store()
        let service = PersonalizationService(defaults: defaults)
        service.sky = .galactic
        service.celebrations = false
        service.haptics = false
        service.autoTagsTopics = false
        let again = PersonalizationService(defaults: defaults)
        #expect(again.sky == .galactic)
        #expect(!again.celebrations && !again.haptics && !again.autoTagsTopics)
        Haptics.isEnabled = true
    }

    @Test func anUnknownSkyFallsBackToCalm() {
        let defaults = store()
        defaults.set("stormy", forKey: DefaultsKey.skyDensity)
        #expect(PersonalizationService(defaults: defaults).sky == .calm)
    }

    /// The four skies of Settings › Personalize › Starry sky: each can be chosen and is there the next time.
    @Test func everySkyOfTheSettingsIsKept() {
        for sky in SkyDensity.allCases {
            let defaults = store()
            PersonalizationService(defaults: defaults).sky = sky
            #expect(PersonalizationService(defaults: defaults).sky == sky, "\(sky)")
        }
        #expect(SkyDensity.allCases == [.off, .calm, .lively, .galactic])
    }

    /// Someone who already chose a sky keeps it: only a creator who never chose gets Calm.
    @Test func aSkyChosenBeforeIsNotChanged() {
        let defaults = store()
        defaults.set(SkyDensity.lively.rawValue, forKey: DefaultsKey.skyDensity)
        #expect(PersonalizationService(defaults: defaults).sky == .lively)
    }

    @Test func theHapticsSwitchReachesTheHapticsHelper() {
        let service = PersonalizationService(defaults: store())
        service.haptics = false
        #expect(!Haptics.isEnabled)
        service.haptics = true
        #expect(Haptics.isEnabled)
    }
}
