//
//  SkyDensityTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Starry sky (Settings › Personalize): what each step draws, and that Off draws no star anywhere.
@Suite("SkyDensity")
struct SkyDensityTests {
    @Test func offDrawsNoStarAnywhere() {
        #expect(SkyDensity.off.twinkleCount == 0)
        #expect(!SkyDensity.off.hasComet)
        #expect(!SkyDensity.off.showsYourStars)
    }

    @Test func sereneIsOnlyTheDriftingStarsAndTheNebulae() {
        #expect(SkyDensity.serene.twinkleCount == 0)
        #expect(!SkyDensity.serene.hasComet)
        #expect(SkyDensity.serene.showsYourStars)
    }

    @Test func adriftHasEverythingAndAnAstronaut() {
        #expect(SkyDensity.adrift.twinkleCount == 14)
        #expect(SkyDensity.adrift.hasComet)
        #expect(SkyDensity.adrift.hasAstronaut)
        #expect(!SkyDensity.adrift.hasSpaceship)
        #expect(SkyDensity.adrift.showsYourStars)
    }

    @Test func interstellarHasTheTwinklesAndASpaceshipInsteadOfTheComet() {
        #expect(SkyDensity.interstellar.twinkleCount == SkyDensity.adrift.twinkleCount)
        #expect(SkyDensity.interstellar.hasSpaceship)
        #expect(!SkyDensity.interstellar.hasComet)
        #expect(SkyDensity.interstellar.isInterstellar)
        #expect(SkyDensity.interstellar.showsYourStars)
    }

    @Test func onlyAdriftHasTheAstronaut() {
        for density in SkyDensity.allCases where density != .adrift {
            #expect(!density.hasAstronaut, "\(density)")
        }
    }

    @Test func onlyInterstellarIsInterstellarAndOnlyItHasASpaceship() {
        for density in SkyDensity.allCases where density != .interstellar {
            #expect(!density.isInterstellar && !density.hasSpaceship, "\(density)")
        }
    }

    @Test func interstellarHasItsOwnLabelAndSavedValue() {
        #expect(SkyDensity.interstellar.rawValue == "interstellar")
        #expect(SkyDensity(rawValue: "interstellar") == .interstellar)
        #expect(!SkyDensity.interstellar.label.isEmpty)
        #expect(Set(SkyDensity.allCases.map(\.label)).count == SkyDensity.allCases.count)
    }

    @Test func aChoiceSavedUnderTheOldNamesStillReads() {
        #expect(SkyDensity(saved: "calm") == .serene)
        #expect(SkyDensity(saved: "lively") == .adrift)
        #expect(SkyDensity(saved: "galactic") == .interstellar)
        #expect(SkyDensity(saved: "off") == .off)
        // And the current names.
        for density in SkyDensity.allCases {
            #expect(SkyDensity(saved: density.rawValue) == density, "\(density)")
        }
        #expect(SkyDensity(saved: "stormy") == nil)
    }

    @Test func thePickerHasFourSteps() {
        #expect(SkyDensity.allCases.map(\.step) == [0, 1, 2, 3])
    }

    /// A choice made in Settings is kept (and read back) by the service, so every screen draws the same sky.
    @MainActor
    @Test func theChosenSkyIsKeptOnThisIPhone() throws {
        let suite = "sky-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let service = PersonalizationService(defaults: defaults)
        #expect(service.sky == .serene)
        service.sky = .off
        #expect(PersonalizationService(defaults: defaults).sky == .off)
        #expect(!PersonalizationService(defaults: defaults).sky.showsYourStars)
    }
}
