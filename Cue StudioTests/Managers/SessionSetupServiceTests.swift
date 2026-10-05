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

    @Test func cameraOptionsStillPersistButReadingEditsStayLocal() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        session.camera.countdown = .ten
        session.prompter.font = .serif
        #expect(preferences.camera.countdown == .ten)
        #expect(session.prompter.font == .serif)
        #expect(preferences.prompter.font == .lexend)
        #expect(session.hasChanges)
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

    @Test func aNewDefaultOnlyAffectsNewSessions() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        session.camera.aspect = .square
        preferences.creatorSetup.resolution = .hd720
        preferences.creatorSetup.aspect = .landscape
        #expect(session.camera.resolution == .uhd4K)
        #expect(session.camera.aspect == .square)
        let next = SessionSetupService(preferences: preferences)
        #expect(next.camera.resolution == .hd720)
        #expect(next.camera.aspect == .landscape)
    }

    @Test func allLocalReadingEditsLeaveSavedDefaultsUntouched() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        let saved = preferences.prompter
        session.prompter.font = .serif
        session.prompter.textColor = .yellow
        session.prompter.lineSpacing = 1.8
        session.prompter.alignment = .trailing
        session.prompter.margin = 24
        session.prompter.readingWidth = 0.6
        session.prompter.textWindowHeight = 200
        session.prompter.readingLineOffset = 200
        session.prompter.backgroundOpacity = 0.8
        session.prompter.cameraBlur = 12
        session.prompter.guidePosition = 0.6
        session.prompter.showsGuide = false
        session.prompter.isMirrored = true
        session.prompter.scrollMode = .voice
        session.prompter.studioBackground = .navy
        session.prompter.showsCues = true
        session.prompter.customSafeZone.top = 20
        session.prompter.size = 40
        session.prompter.speed = 1.8
        #expect(session.hasChanges)
        #expect(preferences.prompter == saved)
        let reloaded = PreferencesService(defaults: defaults.defaults)
        #expect(reloaded.prompter == saved)
        #expect(SessionSetupService(preferences: reloaded).prompter == saved)
        session.backToCreatorSetup()
        #expect(session.prompter == saved)
        #expect(!session.hasChanges)
    }

    @Test func profileEditsCannotChangeAnOpenSessionOrItsExplicitValues() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        session.prompter.textColor = .cream
        session.prompter.size = 42
        session.prompter.readingWidth = 0.7
        let before = session.prompter
        preferences.prompter.font = .serif
        preferences.prompter.textColor = .green
        preferences.prompter.size = 20
        preferences.prompter.readingWidth = 0.9
        preferences.prompter.scrollMode = .voice
        #expect(session.prompter == before)
        #expect(SessionSetupService(preferences: preferences).prompter == preferences.prompter)
    }

    @Test func platformRecommendationsPreservePersonalAppearanceAndLocalEdits() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let preferences = PreferencesService(defaults: defaults.defaults)
        preferences.prompter.font = .rounded
        preferences.prompter.textColor = .cyan
        preferences.prompter.backgroundOpacity = 0.6
        let session = SessionSetupService(preferences: preferences)
        session.prompter.margin = 24
        session.prompter.size = 40
        let before = session.prompter
        session.recommend(SetupRecommendation(platform: .youtube, preset: TestData.preset(.youtube)))
        session.useRecommended()
        #expect(session.camera.aspect == .landscape)
        #expect(session.prompter == before)
        #expect(session.source(of: .textSize) == .thisTake)
        #expect(preferences.prompter.margin == PrompterSettings().margin)
    }

    // MARK: - Remembering the layout

    @Test func theLayoutTheCreatorLeftIsWhatTheNextSessionOpensWith() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        session.prompter.readingLineOffset = 90
        session.prompter.textWindowHeight = 240
        session.prompter.readingWidth = 0.8
        session.prompter.size = 44
        session.prompter.speed = 0.9
        session.prompter.guidePosition = 0.2
        session.prompter.margin = 12
        session.prompter.isMirrored = true
        session.prompter.scrollMode = .voice
        #expect(preferences.prompter.readingLineOffset == nil, "nothing is saved while the session is open")
        session.rememberReadingLayout()
        let next = SessionSetupService(preferences: PreferencesService(defaults: defaults.defaults)).prompter
        #expect(next.readingLineOffset == 90)
        #expect(next.textWindowHeight == 240)
        #expect(next.readingWidth == 0.8)
        #expect(next.size == 44)
        #expect(next.speed == 0.9)
        #expect(next.guidePosition == 0.2)
        #expect(next.margin == 12)
        #expect(next.isMirrored)
        #expect(next.scrollMode == .voice)
    }

    @Test func rememberingTheLayoutLeavesEverythingElseAlone() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (session, preferences) = makeService(defaults)
        session.camera.resolution = .hd720
        session.prompter.font = .serif
        session.prompter.size = 30
        session.rememberReadingLayout()
        #expect(preferences.prompter.size == 30)
        #expect(preferences.prompter.font == .lexend, "only the layout is kept")
        #expect(preferences.camera.resolution == .uhd4K, "a change for one take stays with the take")
    }
}
