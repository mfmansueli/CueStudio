//
//  AppearanceServiceTests.swift
//  Cue StudioTests
//

import Foundation
import SwiftUI
import Testing
@testable import Cue_Studio

/// Settings › Appearance: the iPhone's own, light or dark, kept on this iPhone.
@MainActor
@Suite("Appearance")
struct AppearanceServiceTests {
    private func defaults() -> UserDefaults {
        let name = "studio.cue.tests.appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func followsTheIPhoneUntilTheCreatorPicks() {
        let service = AppearanceService(defaults: defaults())
        #expect(service.appearance == .system)
        #expect(service.appearance.colorScheme == nil)
    }

    @Test func eachChoiceMapsToItsColorScheme() {
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
        #expect(AppAppearance.allCases.count == 3)
    }

    @Test func theChoiceIsKept() {
        let store = defaults()
        AppearanceService(defaults: store).appearance = .light
        #expect(AppearanceService(defaults: store).appearance == .light)
        #expect(store.string(forKey: DefaultsKey.appAppearance) == "light")
    }

    @Test func anUnknownSavedValueFallsBackToTheIPhones() {
        let store = defaults()
        store.set("sepia", forKey: DefaultsKey.appAppearance)
        #expect(AppearanceService(defaults: store).appearance == .system)
    }

    @Test func theRecordTabsRingReadsOnBothTabBars() throws {
        let light = try #require(RecordGlyph.tabImage(for: .light).pngData())
        let dark = try #require(RecordGlyph.tabImage(for: .dark).pngData())
        #expect(light != dark)
    }
}
