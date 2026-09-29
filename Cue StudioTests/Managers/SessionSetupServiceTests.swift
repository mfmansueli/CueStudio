//
//  SessionSetupServiceTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@MainActor
@Suite("SessionSetupService")
struct SessionSetupServiceTests {
    private func makeService(_ defaults: TestDefaults) -> (SessionSetupService, PreferencesService) {
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.creatorSetup = CreatorSetupTests.usual()
        return (SessionSetupService(preferences: preferences), preferences)
    }

    @Test func readsTheCreatorSetup() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, _) = makeService(defaults)
        #expect(session.camera.resolution == .uhd4K)
        #expect(session.camera.microphoneID == "airpods-pro")
        #expect(session.prompter.size == 36)
    }

    @Test func setupChangesStayInTheSession() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        session.camera.resolution = .hd720
        session.prompter.isMirrored = true
        #expect(session.camera.resolution == .hd720)
        #expect(session.prompter.isMirrored)
        #expect(session.source(of: .quality) == .thisTake)
        #expect(preferences.camera.resolution == .uhd4K)
        #expect(!preferences.prompter.isMirrored)
        #expect(PreferencesService(defaults: defaults.defaults).camera.resolution == .uhd4K)
    }

    @Test func otherSettingsAreSavedAsBefore() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        session.camera.countdown = .ten
        session.prompter.font = .serif
        #expect(preferences.camera.countdown == .ten)
        #expect(preferences.prompter.font == .serif)
        #expect(!session.hasChanges)
    }

    @Test func acceptingARecommendationNeverTouchesTheDefault() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        session.recommend(SetupRecommendation(platform: .tiktok, preset: TestData.preset(.tiktok)))
        #expect(session.needsDecision)
        #expect(session.usualSummary == "9:16 · 4K · 30 fps")
        session.useRecommended()
        #expect(session.camera.resolution == .hd1080)
        #expect(preferences.camera.resolution == .uhd4K)
        #expect(preferences.creatorSetup == CreatorSetupTests.usual())
    }

    @Test func keepingTheSetupUsesTheDefault() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, _) = makeService(defaults)
        session.recommend(SetupRecommendation(platform: .tiktok, preset: TestData.preset(.tiktok)))
        session.keepCreatorSetup()
        #expect(session.camera.resolution == .uhd4K)
        #expect(!session.needsDecision)
    }

    @Test func aNewDefaultShowsUpWhereTheSessionHasNoChange() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        session.camera.aspect = .square
        preferences.creatorSetup.resolution = .hd720
        preferences.creatorSetup.aspect = .landscape
        #expect(session.camera.resolution == .hd720)
        #expect(session.camera.aspect == .square)
    }
}
