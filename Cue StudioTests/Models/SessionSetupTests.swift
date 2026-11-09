//
//  SessionSetupTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The hierarchy: a change for this take, then the recommendations used, then the Creator Setup; the lines a recommendation shows, and
/// what Keep as is and Use Recommended do with them.
@Suite("SessionSetup")
struct SessionSetupTests {
    private let usual = CreatorSetupTests.usual()

    private var tiktok: SetupRecommendation {
        SetupRecommendation(platform: .tiktok, preset: TestData.preset(.tiktok))
    }

    @Test func startsFromTheCreatorSetup() {
        let session = SessionSetup()
        #expect(session.resolved(from: usual) == usual)
        #expect(session.source(of: .quality) == .creatorSetup)
    }

    @Test func aRecommendationListsWhatWouldChangeAndIsNotApplied() {
        var session = SessionSetup()
        session.recommend(tiktok)
        let changes = session.changes(from: usual)
        #expect(changes == [SetupChange(item: .field(.quality), current: "4K", recommended: "1080p", isManual: false)])
        #expect(changes.first?.title == "Quality")
        #expect(changes.first?.values == "4K → 1080p")
        #expect(session.resolved(from: usual).resolution == .uhd4K)
    }

    @Test func aMatchingRecommendationHasNothingToChange() {
        var session = SessionSetup()
        session.recommend(tiktok)
        #expect(session.changes(from: CreatorSetup()).isEmpty)
    }

    /// The lines are against what is on screen, not against the Creator Setup: a frame picked for this take is the "now" side, marked.
    @Test func theLinesAreAgainstTheScreenAndMarkTheCreatorsOwnChoices() {
        var session = SessionSetup()
        session.recommend(tiktok)
        var picked = usual
        picked.aspect = .vertical
        session.record(from: usual, to: picked, creatorSetup: usual)
        let changes = session.changes(from: usual)
        #expect(changes.map(\.item) == [.field(.format), .field(.quality)])
        #expect(changes.first == SetupChange(item: .field(.format), current: "4:5", recommended: "9:16", isManual: true))
        #expect(changes.last?.isManual == false)
    }

    @Test func useRecommendedChangesTheSessionOnly() {
        var session = SessionSetup()
        session.recommend(tiktok)
        session.useRecommended()
        #expect(session.resolved(from: usual).resolution == .hd1080)
        #expect(session.source(of: .quality) == .recommended(.tiktok))
        #expect(session.captureSource == .recommended(.tiktok))
        #expect(session.changes(from: usual).isEmpty)
        // The rest is still the creator's.
        #expect(session.resolved(from: usual).textSize == 36)
        #expect(session.source(of: .textSize) == .creatorSetup)
    }

    /// "Keep as is" changes nothing at all, a frame picked for this take included.
    @Test func keepAsIsChangesNothing() {
        var session = SessionSetup()
        var picked = usual
        picked.aspect = .vertical
        session.record(from: usual, to: picked, creatorSetup: usual)
        session.recommend(tiktok)
        let before = session.resolved(from: usual)
        session.keepAsIs()
        #expect(session.resolved(from: usual) == before)
        #expect(session.choice == .keepAsIs)
        #expect(session.source(of: .format) == .thisTake)
    }

    /// Asking for another network never changes the screen: what the first "Use Recommended" set stays until the creator answers.
    @Test func anotherNetworkAsksWithoutChangingTheScreen() {
        var session = SessionSetup()
        session.recommend(tiktok)
        session.useRecommended()
        let tiktokSetup = session.resolved(from: usual)
        session.recommend(SetupRecommendation(platform: .youtube, preset: TestData.preset(.youtube)))
        #expect(session.resolved(from: usual) == tiktokSetup)
        #expect(!session.changes(from: usual).isEmpty)
        session.keepAsIs()
        #expect(session.resolved(from: usual) == tiktokSetup)
    }

    @Test func aManualChoiceWinsOverTheRecommendation() {
        // Creator Setup: front. Recommendation: back. The creator picks front for this video.
        let backCamera = SetupRecommendation(platform: .youtube, values: SetupValues(lens: .wide))
        var session = SessionSetup()
        session.recommend(backCamera)
        session.useRecommended()
        let recommended = session.resolved(from: usual)
        #expect(recommended.lens == .wide)

        var picked = recommended
        picked.lens = .front
        session.record(from: recommended, to: picked, creatorSetup: usual)

        #expect(session.resolved(from: usual).lens == .front)
        #expect(session.source(of: .camera) == .thisTake)
        #expect(usual.lens == .front)
    }

    @Test func aChangeBackToTheUsualValueIsNotAnOverride() {
        var session = SessionSetup()
        var faster = usual
        faster.speed = 1.5
        session.record(from: usual, to: faster, creatorSetup: usual)
        #expect(session.source(of: .speed) == .thisTake)
        session.record(from: faster, to: usual, creatorSetup: usual)
        #expect(session.source(of: .speed) == .creatorSetup)
        #expect(session.overrides.isEmpty)
    }

    @Test func acceptingARecommendationReplacesEarlierChangesToItsFields() {
        var session = SessionSetup()
        session.recommend(tiktok)
        var changed = usual
        changed.resolution = .hd720
        session.record(from: usual, to: changed, creatorSetup: usual)
        session.useRecommended()
        #expect(session.resolved(from: usual).resolution == .hd1080)
    }

    @Test func recordingUndecidedKeepsWhatIsOnScreen() {
        var session = SessionSetup()
        session.recommend(tiktok)
        session.settleUndecided()
        #expect(session.choice == .keepAsIs)
        #expect(session.resolved(from: usual).resolution == .uhd4K)
    }

    @Test func anotherPlatformAsksAgain() {
        var session = SessionSetup()
        session.recommend(tiktok)
        session.keepAsIs()
        session.recommend(SetupRecommendation(platform: .youtube, preset: TestData.preset(.youtube)))
        #expect(session.choice == .undecided)
        session.recommend(SetupRecommendation(platform: .youtube, preset: TestData.preset(.youtube)))
        #expect(session.choice == .undecided)
    }

    @Test func backToMySetupDropsEverything() {
        var session = SessionSetup()
        session.recommend(tiktok)
        session.useRecommended()
        var changed = session.resolved(from: usual)
        changed.isMirrored = true
        session.record(from: session.resolved(from: usual), to: changed, creatorSetup: usual)
        session.backToCreatorSetup()
        #expect(session.resolved(from: usual) == usual)
        #expect(session.choice == .keepAsIs)
    }

    @Test func theRecommendationSummaryNamesTheSafeZone() {
        #expect(tiktok.title == "Recommended for TikTok")
        #expect(tiktok.summary == "9:16 · 1080p · 30 fps · TikTok safe zone")
        #expect(SetupRecommendation(platform: .youtube, preset: TestData.preset(.youtube)).summary == "16:9 · 4K · 24 fps")
    }
}
