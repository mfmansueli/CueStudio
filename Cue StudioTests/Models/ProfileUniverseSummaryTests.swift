//
//  ProfileUniverseSummaryTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The "Your universe" row of the Profile (9.1) in its three states.
@Suite("Profile universe summary")
struct ProfileUniverseSummaryTests {
    @Test func aUniverseWithVideos() {
        let summary = ProfileUniverseSummary(total: 23, sharedThisYear: 23, year: 2026, lastYear: 2026, lastYearCount: 23, topics: 3, toNextMilestone: 2)
        #expect(summary.trailing == "23 videos")
        #expect(summary.detail == "2026 · 3 topics")
        #expect(summary.footer == "2 more videos to your next milestone.")
    }

    @Test func aNewAccountStartsWithTheFirstShare() {
        let summary = ProfileUniverseSummary(total: 0, sharedThisYear: 0, year: 2026, lastYear: 2026, lastYearCount: 0, topics: 3, toNextMilestone: 1)
        #expect(summary.isNewAccount && !summary.isNewYear)
        #expect(summary.trailing == "0 videos")
        #expect(summary.detail == "Starts with your first share")
        #expect(summary.footer == "Share a video to light your first star.")
    }

    @Test func aNewYearSaysWhatLastYearHad() {
        let summary = ProfileUniverseSummary(total: 23, sharedThisYear: 0, year: 2027, lastYear: 2026, lastYearCount: 23, topics: 3, toNextMilestone: 2)
        #expect(summary.isNewYear)
        #expect(summary.trailing == "0 videos")
        #expect(summary.detail == "2026 · 23 videos")
        #expect(summary.footer == "Your 2027 universe starts with your first share.")
    }

    @Test func afterTheLastMilestoneThereIsNothingLeftToCount() {
        let summary = ProfileUniverseSummary(total: 600, sharedThisYear: 40, year: 2026, lastYear: 2025, lastYearCount: 560, topics: 3, toNextMilestone: nil)
        #expect(summary.footer == "Every milestone is behind you")
    }
}
