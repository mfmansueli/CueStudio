//
//  UniverseContentTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The four states of "Your universe" (9.2) and what each one says and does.
@Suite("UniverseContent")
struct UniverseContentTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int = 6, _ day: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func videos(_ count: Int, year: Int, platform: Platform = .tiktok) -> [UniverseVideo] {
        (0..<count).map { UniverseVideo(date: date(year, 1 + $0 % 12), platform: platform) }
    }

    private func content(_ videos: [UniverseVideo], year: Int? = nil, now: Date? = nil) -> UniverseContent {
        UniverseContent(videos: videos, topics: [], selectedYear: year, now: now ?? date(2026), calendar: calendar)
    }

    // MARK: - The four states

    @Test func aNewAccountHasNoSelectorAndStartsWithTheFirstShare() {
        let content = content([])
        #expect(content.state == .newAccount && !content.showsSelector)
        #expect(content.headline == "NO VIDEOS SHARED YET")
        #expect(content.caption == "Your universe starts with your first share.")
        #expect(content.action == .record && content.actionTitle == "Record your first video")
        #expect(content.ghost == nil)
    }

    @Test func aNewYearShowsLastYearAndItsEmptyUniverse() {
        let content = content(videos(23, year: 2026), year: 2027, now: date(2027, 1, 3))
        #expect(content.state == .newYear)
        #expect(content.years == [2026, 2027], "2027 is current, 2026 is behind it")
        #expect(content.headline == "0 VIDEOS SHARED IN 2027")
        #expect(content.caption == "Your 2027 universe starts with your first share.")
        #expect(content.ghost?.total == 23, "last year's universe shows very faint behind")
        #expect(content.review.title == "Your 2026 in review")
        #expect(content.review.line == "4 MOMENTS · READY TO SHARE", "total, planet, month and streak: no topics, no theme slide")
        #expect(content.reviewSwitchesYear)
        #expect(content.action == .share(year: 2026) && content.actionTitle == "Share my 2026 universe")
    }

    @Test func theLiveYearCountsAndSaysSo() {
        let content = content(videos(23, year: 2026))
        #expect(content.state == .live && !content.isSealed && content.sealedBadge == nil)
        #expect(content.headline == "23 VIDEOS SHARED IN 2026")
        #expect(content.caption == nil)
        #expect(content.actionTitle == "Share my 2026 universe")
        #expect(content.review.line == "PREVIEW · READY DEC 1" && !content.review.isLocked)
    }

    @Test func aPastYearIsSealed() {
        let all = videos(23, year: 2026) + videos(41, year: 2025)
        let content = content(all, year: 2025)
        #expect(content.state == .sealed && content.isSealed)
        #expect(content.headline == "41 VIDEOS SHARED IN 2025 · SEALED")
        #expect(content.sealedBadge == "◆ SEALED · DEC 31, 2025")
        #expect(content.ghost == nil, "only the live year has the ghost")
        #expect(content.years == [2025, 2026])
    }

    // MARK: - The story

    @Test func theStoryNeedsThreeVideos() {
        let none = content([]).review
        #expect(none.isLocked && none.line == "3 VIDEOS TO UNLOCK" && none.title == "Your year in review" && none.count == 0)
        let one = content(videos(1, year: 2026)).review
        #expect(one.isLocked && one.line == "2 MORE TO UNLOCK")
        #expect(!content(videos(3, year: 2026)).review.isLocked)
    }

    @Test func theLiveYearsStoryIsReadyInDecember() {
        let december = content(videos(23, year: 2026), now: date(2026, 12, 2)).review
        #expect(december.line.hasSuffix("MOMENTS · READY TO SHARE"))
    }

    @Test func aSealedYearsCard() throws {
        var all = (0..<9).map { UniverseVideo(date: date(2025, 10, 1 + $0), platform: .tiktok) }
        all += [UniverseVideo(date: date(2025, 2), platform: .reels)]
        let card = try #require(content(all, year: 2025).yearCard)
        #expect(card.eyebrow == "2025 · YOUR YEAR")
        #expect(card.title == "10 videos · TikTok was your main planet")
        #expect(card.detail.hasPrefix("Best month October"))
        #expect(content(videos(3, year: 2026)).yearCard == nil)
    }

    @Test func theYearsOfTheSelectorAreTheLastThree() {
        let all = videos(1, year: 2023) + videos(1, year: 2024) + videos(1, year: 2025) + videos(1, year: 2026)
        #expect(content(all).years == [2024, 2025, 2026])
    }
}
