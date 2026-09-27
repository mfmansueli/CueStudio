//
//  PreferencesServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("PreferencesService")
struct PreferencesServiceTests {
    @Test func settingsPersist() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = PreferencesService(defaults: store.defaults)
        service.prompter.size = 40
        service.camera.codec = .h264
        let reloaded = PreferencesService(defaults: store.defaults)
        #expect(reloaded.prompter.size == 40)
        #expect(reloaded.camera.codec == .h264)
    }

    @Test func unreadableSettingsFallBackToDefaults() {
        let store = TestDefaults()
        defer { store.tearDown() }
        store.defaults.set(Data("not json".utf8), forKey: DefaultsKey.prompterSettings)
        let service = PreferencesService(defaults: store.defaults)
        #expect(service.prompter == PrompterSettings())
    }
}
