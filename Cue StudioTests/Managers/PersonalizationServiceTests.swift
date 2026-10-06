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

    @Test func itStartsWithTheSereneSkyAndEverythingOn() {
        let service = PersonalizationService(defaults: store())
        #expect(service.sky == .serene)
        #expect(service.celebrations && service.haptics && service.autoTagsTopics)
    }

    @Test func theChoicesAreKept() {
        let defaults = store()
        let service = PersonalizationService(defaults: defaults)
        service.sky = .interstellar
        service.celebrations = false
        service.haptics = false
        service.autoTagsTopics = false
        let again = PersonalizationService(defaults: defaults)
        #expect(again.sky == .interstellar)
        #expect(!again.celebrations && !again.haptics && !again.autoTagsTopics)
        Haptics.isEnabled = true
    }

    @Test func anUnknownSkyFallsBackToSerene() {
        let defaults = store()
        defaults.set("stormy", forKey: DefaultsKey.skyDensity)
        #expect(PersonalizationService(defaults: defaults).sky == .serene)
    }

    /// The four skies of Settings › Personalize › Starry sky: each can be chosen and is there the next time.
    @Test func everySkyOfTheSettingsIsKept() {
        for sky in SkyDensity.allCases {
            let defaults = store()
            PersonalizationService(defaults: defaults).sky = sky
            #expect(PersonalizationService(defaults: defaults).sky == sky, "\(sky)")
        }
        #expect(SkyDensity.allCases == [.off, .serene, .adrift, .interstellar])
    }

    /// Someone who already chose a sky keeps it, even if it was saved under the name it had before the renaming (Calm, Lively, Galactic).
    @Test func aSkySavedUnderItsOldNameIsKept() {
        for (old, sky) in [("calm", SkyDensity.serene), ("lively", .adrift), ("galactic", .interstellar)] {
            let defaults = store()
            defaults.set(old, forKey: DefaultsKey.skyDensity)
            #expect(PersonalizationService(defaults: defaults).sky == sky, "\(old)")
        }
    }

    /// Someone who already chose a sky keeps it: only a creator who never chose gets Serene.
    @Test func aSkyChosenBeforeIsNotChanged() {
        let defaults = store()
        defaults.set(SkyDensity.adrift.rawValue, forKey: DefaultsKey.skyDensity)
        #expect(PersonalizationService(defaults: defaults).sky == .adrift)
    }

    @Test func theHapticsSwitchReachesTheHapticsHelper() {
        let service = PersonalizationService(defaults: store())
        service.haptics = false
        #expect(!Haptics.isEnabled)
        service.haptics = true
        #expect(Haptics.isEnabled)
    }
}
