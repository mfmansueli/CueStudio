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

    /// Test 1: Front, AirPods, 4K, 9:16, Large, a set speed — still there after relaunching.
    @Test func creatorSetupPersists() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = PreferencesService(defaults: store.defaults)
        service.creatorSetup = CreatorSetupTests.usual()
        let reloaded = PreferencesService(defaults: store.defaults)
        #expect(reloaded.creatorSetup == CreatorSetupTests.usual())
        #expect(reloaded.camera.microphoneName == "AirPods Pro")
    }

    /// Test 8: the teleprompter defaults.
    @Test func teleprompterDefaultsPersist() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = PreferencesService(defaults: store.defaults)
        service.creatorSetup.textSize = PrompterTextSize.small.points
        service.creatorSetup.speed = 1.1
        service.creatorSetup.readingLine = .offset(150)
        service.creatorSetup.isMirrored = true
        service.creatorSetup.showsSafeZones = false
        let reloaded = PreferencesService(defaults: store.defaults).creatorSetup
        #expect(reloaded.textSize == 22)
        #expect(reloaded.speed == 1.1)
        #expect(reloaded.readingLine == .offset(150))
        #expect(reloaded.isMirrored)
        #expect(!reloaded.showsSafeZones)
    }

    @Test func settingsSavedBeforeTheMicrophoneNameStillLoad() throws {
        let store = TestDefaults()
        defer { store.tearDown() }
        var camera = CameraSettings()
        camera.resolution = .uhd4K
        camera.microphoneID = "usb-mic"
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(camera)) as? [String: Any])
        json.removeValue(forKey: "microphoneName")
        store.defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: DefaultsKey.cameraSettings)
        let service = PreferencesService(defaults: store.defaults)
        #expect(service.camera.resolution == .uhd4K)
        #expect(service.creatorSetup.microphone == .input(id: "usb-mic", name: "Microphone"))
    }

    @Test func resetCreatorSetupRestoresRecordingAndReadingDefaults() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = PreferencesService(defaults: store.defaults)
        service.creatorSetup = CreatorSetupTests.usual()
        service.camera.countdown = .ten
        service.prompter.font = .serif
        service.resetCreatorSetup()
        #expect(service.creatorSetup == CreatorSetup())
        #expect(service.camera.countdown == .ten)
        #expect(service.prompter == PrompterSettings())
    }

    @Test func existingStoredAppearanceBecomesTheCreatorDefaultWithoutRewritingIt() throws {
        let store = TestDefaults()
        defer { store.tearDown() }
        var old = PrompterSettings()
        old.font = .serif
        old.size = 38
        old.textColor = .cream
        old.readingWidth = 0.63
        old.textWindowHeight = 220
        old.readingLineOffset = 190
        old.cameraBlur = 6
        old.scrollMode = .voice
        let data = try JSONEncoder().encode(old)
        store.defaults.set(data, forKey: DefaultsKey.prompterSettings)
        let preferences = PreferencesService(defaults: store.defaults)
        let session = SessionSetupService(preferences: preferences)
        #expect(session.prompter == old)
        #expect(store.defaults.data(forKey: DefaultsKey.prompterSettings) == data)
        session.prompter.font = .rounded
        #expect(store.defaults.data(forKey: DefaultsKey.prompterSettings) == data)
    }

    @Test func unreadableSettingsFallBackToDefaults() {
        let store = TestDefaults()
        defer { store.tearDown() }
        store.defaults.set(Data("not json".utf8), forKey: DefaultsKey.prompterSettings)
        let service = PreferencesService(defaults: store.defaults)
        #expect(service.prompter == PrompterSettings())
    }
}
