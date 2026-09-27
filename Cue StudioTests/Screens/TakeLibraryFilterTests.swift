//
//  TakeLibraryFilterTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("TakeLibraryFilter")
struct TakeLibraryFilterTests {
    private let now = TestData.now
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private let scriptA = UUID()
    private let scriptB = UUID()

    private func take(
        _ scriptID: UUID?, _ number: Int, hoursAgo: Double, platform: Platform? = .tiktok,
        best: Bool = false, edited: Bool = false, exported: Bool = false
    ) -> Take {
        var take = TestData.take(scriptID: scriptID, title: scriptID == nil ? "Freestyle recording" : "Script", number: number, recordedAt: now.addingTimeInterval(-hoursAgo * 3600), isBest: best)
        take.platform = platform
        take.isEdited = edited
        take.isExported = exported
        return take
    }

    @Test func oneVideoPerScriptAndOnePerFreestyleTake() {
        let takes = [
            take(scriptA, 1, hoursAgo: 3), take(scriptA, 2, hoursAgo: 2),
            take(nil, 1, hoursAgo: 1, platform: nil), take(nil, 2, hoursAgo: 0.5, platform: nil),
            take(scriptB, 1, hoursAgo: 5),
        ]
        let videos = TakeLibraryFilter.videos(from: takes)
        #expect(videos.count == 4)
        #expect(videos.first?.title == "Freestyle recording")
        #expect(videos.first { $0.takes.first?.scriptID == scriptA }?.takes.map(\.number) == [2, 1])
    }

    @Test func bestIsTheMarkedTakeOrTheNewest() {
        let marked = TakeLibraryFilter.videos(from: [take(scriptA, 1, hoursAgo: 2, best: true), take(scriptA, 2, hoursAgo: 1)])[0]
        #expect(marked.best?.number == 1)
        #expect(marked.takesLabel == "2 takes · Best: Take 1")
        let unmarked = TakeLibraryFilter.videos(from: [take(scriptA, 1, hoursAgo: 2), take(scriptA, 2, hoursAgo: 1)])[0]
        #expect(unmarked.best?.number == 2)
        #expect(unmarked.takesLabel == "2 takes")
    }

    @Test func aSingleTakeHasNoTakesChip() {
        #expect(TakeLibraryFilter.videos(from: [take(scriptA, 1, hoursAgo: 1)])[0].takesLabel == nil)
    }

    @Test func theScriptsCurrentPlatformWins() {
        let videos = TakeLibraryFilter.videos(from: [take(scriptA, 1, hoursAgo: 1, platform: .tiktok)]) { _ in .youtube }
        #expect(videos[0].platform == .youtube)
    }

    @Test func platformAndViewFiltersCombine() {
        let videos = TakeLibraryFilter.videos(from: [
            take(scriptA, 1, hoursAgo: 1, platform: .reels, best: true, exported: true),
            take(scriptB, 1, hoursAgo: 1, platform: .tiktok, edited: true),
        ])
        #expect(TakeLibraryFilter(platform: .reels).apply(to: videos).count == 1)
        #expect(TakeLibraryFilter(view: .best).apply(to: videos).map(\.platform) == [.reels])
        #expect(TakeLibraryFilter(view: .notShared).apply(to: videos).map(\.platform) == [.tiktok])
        #expect(TakeLibraryFilter(view: .edited).apply(to: videos).map(\.platform) == [.tiktok])
        #expect(TakeLibraryFilter(platform: .reels, view: .edited).apply(to: videos).isEmpty)
    }

    @Test func sectionsFollowTheNewestTakeOfEachVideo() {
        let videos = TakeLibraryFilter.videos(from: [
            take(scriptA, 1, hoursAgo: 60), take(scriptA, 2, hoursAgo: 1),
            take(scriptB, 1, hoursAgo: 30),
            take(nil, 1, hoursAgo: 24 * 9, platform: nil),
        ])
        let sections = TakeLibraryFilter().sections(of: videos, now: now, calendar: calendar)
        #expect(sections.map(\.day) == [.today, .yesterday, .earlier])
        #expect(sections[0].videos.first?.takes.count == 2)
    }

    @Test func emptyDaysAreLeftOut() {
        let videos = TakeLibraryFilter.videos(from: [take(scriptA, 1, hoursAgo: 1)])
        #expect(TakeLibraryFilter().sections(of: videos, now: now, calendar: calendar).map(\.day) == [.today])
    }
}
