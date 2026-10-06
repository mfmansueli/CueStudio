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

    @Test func calmIsOnlyTheDriftingStarsAndTheNebulae() {
        #expect(SkyDensity.calm.twinkleCount == 0)
        #expect(!SkyDensity.calm.hasComet)
        #expect(SkyDensity.calm.showsYourStars)
    }

    @Test func livelyHasEverything() {
        #expect(SkyDensity.lively.twinkleCount == 14)
        #expect(SkyDensity.lively.hasComet)
        #expect(!SkyDensity.lively.hasSpaceship)
        #expect(SkyDensity.lively.showsYourStars)
    }

    @Test func galacticHasLivelysTwinklesAndASpaceshipInsteadOfTheComet() {
        #expect(SkyDensity.galactic.twinkleCount == SkyDensity.lively.twinkleCount)
        #expect(SkyDensity.galactic.hasSpaceship)
        #expect(!SkyDensity.galactic.hasComet)
        #expect(SkyDensity.galactic.isGalactic)
        #expect(SkyDensity.galactic.showsYourStars)
    }

    @Test func onlyGalacticIsGalacticAndOnlyItHasASpaceship() {
        for density in SkyDensity.allCases where density != .galactic {
            #expect(!density.isGalactic && !density.hasSpaceship, "\(density)")
        }
    }

    @Test func galacticHasItsOwnLabelAndSavedValue() {
        #expect(SkyDensity.galactic.rawValue == "galactic")
        #expect(SkyDensity(rawValue: "galactic") == .galactic)
        #expect(!SkyDensity.galactic.label.isEmpty)
        #expect(Set(SkyDensity.allCases.map(\.label)).count == SkyDensity.allCases.count)
    }

    @Test func theSavedChoiceOfEarlierVersionsStillReads() {
        #expect(SkyDensity(rawValue: "calm") == .calm)
        #expect(SkyDensity(rawValue: "lively") == .lively)
        #expect(SkyDensity(rawValue: "off") == .off)
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
        #expect(service.sky == .calm)
        service.sky = .off
        #expect(PersonalizationService(defaults: defaults).sky == .off)
        #expect(!PersonalizationService(defaults: defaults).sky.showsYourStars)
    }
}
