//
//  SessionSetupTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The hierarchy: a change for this take, then an accepted recommendation, then the Creator Setup.
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

    @Test func aConflictingRecommendationAsksAndIsNotApplied() {
        var session = SessionSetup()
        session.recommend(tiktok)
        let conflicts = session.conflicts(with: usual)
        #expect(conflicts == [SetupConflict(field: .quality, recommended: "1080p", usual: "4K")])
        #expect(conflicts.first?.sentence == "1080p instead of your usual 4K.")
        #expect(session.needsDecision(with: usual))
        #expect(session.resolved(from: usual).resolution == .uhd4K)
    }

    @Test func aMatchingRecommendationHasNothingToAsk() {
        var session = SessionSetup()
        session.recommend(tiktok)
        #expect(!session.needsDecision(with: CreatorSetup()))
    }

    @Test func useRecommendedChangesTheSessionOnly() {
        var session = SessionSetup()
        session.recommend(tiktok)
        session.useRecommended()
        #expect(session.resolved(from: usual).resolution == .hd1080)
        #expect(session.source(of: .quality) == .recommended(.tiktok))
        #expect(session.captureSource == .recommended(.tiktok))
        #expect(!session.needsDecision(with: usual))
        // The rest is still the creator's.
        #expect(session.resolved(from: usual).textSize == 36)
        #expect(session.source(of: .textSize) == .creatorSetup)
    }

    @Test func keepMySetupUsesTheCreatorSetup() {
        var session = SessionSetup()
        session.recommend(tiktok)
        session.keepCreatorSetup()
        #expect(session.resolved(from: usual).resolution == .uhd4K)
        #expect(!session.needsDecision(with: usual))
        #expect(session.captureSource == .creatorSetup)
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

    @Test func recordingUndecidedKeepsTheCreatorSetup() {
        var session = SessionSetup()
        session.recommend(tiktok)
        session.settleUndecided()
        #expect(session.choice == .keepCreatorSetup)
        #expect(session.resolved(from: usual).resolution == .uhd4K)
    }

    @Test func anotherPlatformAsksAgain() {
        var session = SessionSetup()
        session.recommend(tiktok)
        session.keepCreatorSetup()
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
        #expect(session.choice == .keepCreatorSetup)
    }

    @Test func theRecommendationSummaryNamesTheSafeZone() {
        #expect(tiktok.title == "Recommended for TikTok")
        #expect(tiktok.summary == "9:16 · 1080p · 30 fps · TikTok safe zone")
        #expect(SetupRecommendation(platform: .youtube, preset: TestData.preset(.youtube)).summary == "16:9 · 4K · 24 fps")
    }
}
