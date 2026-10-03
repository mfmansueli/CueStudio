//
//  LanguageSettingsServiceTests.swift
//  Cue StudioTests
//

import Foundation
import SwiftUI
import Testing
@testable import Cue_Studio

@MainActor
@Suite("LanguageSettingsService")
struct LanguageSettingsServiceTests {
    private func makeService(
        defaults: TestDefaults, interface: FakeInterfaceLanguage = FakeInterfaceLanguage()
    ) -> LanguageSettingsService {
        LanguageSettingsService(defaults: defaults.defaults, applier: interface)
    }

    @Test func startsFollowingTheIPhoneAndEachScript() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let interface = FakeInterfaceLanguage()
        let service = makeService(defaults: defaults, interface: interface)
        #expect(service.appLanguage == nil)
        #expect(service.voiceFollowingLanguage == .sameAsScript)
        #expect(service.scriptLanguage == nil)
        #expect(service.interfaceLocale == nil)
        #expect(interface.applied.isEmpty)
    }

    @Test func appLanguageChangesOnlyTheInterface() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let interface = FakeInterfaceLanguage()
        let service = makeService(defaults: defaults, interface: interface)
        service.voiceFollowingLanguage = .language(.portugueseBrazil)
        service.scriptLanguage = .portugueseBrazil

        service.appLanguage = .english
        #expect(interface.applied == ["en"])
        #expect(service.interfaceLocale == Locale(identifier: "en"))
        #expect(service.voiceFollowingLanguage == .language(.portugueseBrazil))
        #expect(service.scriptLanguage == .portugueseBrazil)

        service.appLanguage = .italian
        #expect(service.voiceFollowingLanguage == .language(.portugueseBrazil))
        #expect(service.scriptLanguage == .portugueseBrazil)
    }

    @Test func voiceAndScriptLanguagesDontTouchTheInterface() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let interface = FakeInterfaceLanguage()
        let service = makeService(defaults: defaults, interface: interface)
        service.appLanguage = .japanese
        service.voiceFollowingLanguage = .language(.english)
        service.scriptLanguage = .english
        #expect(interface.applied == ["ja"])
        #expect(service.appLanguage == .japanese)
        service.scriptLanguage = .portugueseBrazil
        #expect(service.voiceFollowingLanguage == .language(.english))
    }

    @Test func everyChoiceSurvivesARelaunch() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let interface = FakeInterfaceLanguage()
        let service = makeService(defaults: defaults, interface: interface)
        service.appLanguage = .english
        service.voiceFollowingLanguage = .language(.portugueseBrazil)
        service.scriptLanguage = .portugueseBrazil

        let relaunched = makeService(defaults: defaults, interface: interface)
        #expect(relaunched.appLanguage == .english)
        #expect(relaunched.voiceFollowingLanguage == .language(.portugueseBrazil))
        #expect(relaunched.scriptLanguage == .portugueseBrazil)
        #expect(relaunched.interfaceLocale == Locale(identifier: "en"))
    }

    @Test func followingTheIPhoneAgainForgetsTheChoice() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let interface = FakeInterfaceLanguage()
        let service = makeService(defaults: defaults, interface: interface)
        service.appLanguage = .arabic
        #expect(service.layoutDirection == .rightToLeft)
        service.appLanguage = nil
        #expect(interface.applied == ["ar", nil])
        #expect(makeService(defaults: defaults, interface: interface).appLanguage == nil)
    }

    @Test func aLanguagePickedInTheSystemSettingsWins() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let service = makeService(defaults: defaults, interface: FakeInterfaceLanguage())
        service.appLanguage = .english
        // Settings › Cue › Language set German while Cue was closed.
        let relaunched = makeService(defaults: defaults, interface: FakeInterfaceLanguage(systemAppLanguage: "de"))
        #expect(relaunched.appLanguage == .german)
    }

    @Test func voiceFollowingLanguageStorage() {
        #expect(VoiceFollowingLanguage(storageValue: nil) == .sameAsScript)
        #expect(VoiceFollowingLanguage(storageValue: "script") == .sameAsScript)
        #expect(VoiceFollowingLanguage(storageValue: "pt-BR") == .language(.portugueseBrazil))
        #expect(VoiceFollowingLanguage(storageValue: "xx") == .sameAsScript)
        for language in CueLanguage.allCases {
            let choice = VoiceFollowingLanguage.language(language)
            #expect(VoiceFollowingLanguage(storageValue: choice.storageValue) == choice)
        }
    }
}
