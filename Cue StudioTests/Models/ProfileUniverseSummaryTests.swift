//
//  ProfileUniverseSummaryTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The "Your universe" card of the Profile (9.1) in its three states, and the planets of its mini universe.
@Suite("Profile universe summary")
struct ProfileUniverseSummaryTests {
    @Test func aUniverseWithVideos() {
        let summary = ProfileUniverseSummary(total: 23, sharedThisYear: 23, year: 2026, lastYear: 2026, lastYearCount: 23)
        #expect(summary.title == "Your universe")
        #expect(summary.detail == "2026 · 23 videos")
    }

    @Test func oneVideoIsSingular() {
        let summary = ProfileUniverseSummary(total: 1, sharedThisYear: 1, year: 2026, lastYear: 2026, lastYearCount: 1)
        #expect(summary.detail == "2026 · 1 video")
    }

    @Test func aNewAccountIsWaiting() {
        let summary = ProfileUniverseSummary(total: 0, sharedThisYear: 0, year: 2026, lastYear: 2026, lastYearCount: 0)
        #expect(summary.isNewAccount && !summary.isNewYear)
        #expect(summary.title == "Your universe is waiting")
        #expect(summary.detail == "Share your first video and its planet appears here.")
    }

    @Test func aNewYearStartsWithItsFirstShare() {
        let summary = ProfileUniverseSummary(total: 23, sharedThisYear: 0, year: 2027, lastYear: 2026, lastYearCount: 23)
        #expect(summary.isNewYear)
        #expect(summary.title == "Your universe")
        #expect(summary.detail == "Your 2027 universe starts with your first share.")
    }

    /// One planet per network, the most shared first; a video sent to two networks counts for both.
    @Test func thePlanetsAreTheNetworksMostSharedFirst() {
        let networks = ProfileUniverseSummary.networks(of: [[.tiktok], [.reels, .tiktok], [.shorts], [.tiktok]])
        #expect(networks == [.tiktok, .reels, .shorts])
        #expect(ProfileUniverseSummary.networks(of: []).isEmpty)
    }
}
