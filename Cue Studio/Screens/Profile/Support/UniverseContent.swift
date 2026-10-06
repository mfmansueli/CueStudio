//
//  UniverseContent.swift
//  Cue Studio
//

import Foundation

/// Everything "Your universe" (9.2) shows for the year that is selected, decided in one place: which of its four states it is in, what the line under
/// the title says, which card, which review row and what the yellow button does. Pure, so every state is tested without a screen or the clock.
nonisolated struct UniverseContent: Sendable {
    enum State: Equatable, Sendable {
        /// Nothing was ever shared.
        case newAccount
        /// The year has begun and nothing has been shared in it yet, though earlier years have videos.
        case newYear
        case live
        case sealed
    }

    /// What the yellow button does.
    enum Action: Equatable, Sendable {
        case record
        /// Opens the share sheet for this year (switching to it first when it is not the selected one).
        case share(year: Int)
    }

    let videos: [UniverseVideo]
    let topics: [OnboardingTopic]
    let selectedYear: Int
    let now: Date
    let calendar: Calendar

    init(videos: [UniverseVideo], topics: [OnboardingTopic], selectedYear: Int? = nil, now: Date = .now, calendar: Calendar = .current) {
        self.videos = videos
        self.topics = topics
        self.now = now
        self.calendar = calendar
        self.selectedYear = selectedYear ?? UniverseYears.current(now: now, calendar: calendar)
    }

    // MARK: - Years

    var liveYear: Int { UniverseYears.current(now: now, calendar: calendar) }

    var years: [Int] { UniverseYears.selector(videos: videos, now: now, calendar: calendar) }

    /// The selector only exists once something was shared.
    var showsSelector: Bool { !videos.isEmpty }

    var snapshot: UniverseSnapshot { UniverseSnapshot(videos: videos, year: selectedYear, topics: topics, calendar: calendar) }

    /// Last year, very faint behind the live year.
    var ghost: UniverseSnapshot? {
        guard state == .live || state == .newYear else { return nil }
        let before = UniverseSnapshot(videos: videos, year: selectedYear - 1, topics: topics, calendar: calendar)
        return before.total > 0 ? before : nil
    }

    var state: State {
        if videos.isEmpty { return .newAccount }
        if snapshot.total == 0 && selectedYear == liveYear { return .newYear }
        return UniverseYears.isSealed(selectedYear, now: now, calendar: calendar) ? .sealed : .live
    }

    var isSealed: Bool { state == .sealed }

    // MARK: - Words

    /// "23 VIDEOS SHARED IN 2026", with " · SEALED" for a year that is over; "NO VIDEOS SHARED YET" for a new account.
    var headline: String {
        let total = snapshot.total
        switch state {
        case .newAccount: return String(localized: "NO VIDEOS SHARED YET")
        case .sealed: return String(localized: "\(total) VIDEOS SHARED IN \(String(selectedYear)) · SEALED")
        case .live, .newYear: return String(localized: "\(total) VIDEOS SHARED IN \(String(selectedYear))")
        }
    }

    /// "◆ SEALED · DEC 31, 2025", on a sealed year.
    var sealedBadge: String? { isSealed ? String(localized: "◆ SEALED · DEC 31, \(String(selectedYear))") : nil }

    /// Under the core when there is nothing else to draw.
    var caption: String? {
        switch state {
        case .newAccount: String(localized: "Your universe starts with your first share.")
        case .newYear: String(localized: "Your \(String(selectedYear)) universe starts with your first share.")
        case .live, .sealed: nil
        }
    }

    // MARK: - The story

    /// The year the review row and the yellow button are about: the selected one, or the year before it while this one is empty.
    var reviewYear: Int { UniverseYears.reviewYear(selected: selectedYear, videos: videos, calendar: calendar) }

    var reviewStats: YearStats { YearStats(videos: videos, year: reviewYear, topics: topics, calendar: calendar) }

    var review: UniverseReviewRow {
        let stats = reviewStats
        let count = state == .newAccount ? 0 : stats.total
        guard count >= YearStats.videosToUnlock else {
            let missing = YearStats.videosToUnlock - count
            let line = count == 0 ? String(localized: "\(missing) VIDEOS TO UNLOCK") : String(localized: "\(missing) MORE TO UNLOCK")
            let title = state == .newAccount ? String(localized: "Your year in review") : String(localized: "Your \(String(reviewYear)) in review")
            return UniverseReviewRow(isLocked: true, title: title, line: line, count: count, year: reviewYear)
        }
        let ready = UniverseYears.storyIsReady(year: reviewYear, now: now, calendar: calendar)
        let line = ready ? String(localized: "\(stats.slides.count) MOMENTS · READY TO SHARE") : String(localized: "PREVIEW · READY DEC 1")
        return UniverseReviewRow(isLocked: false, title: String(localized: "Your \(String(reviewYear)) in review"), line: line, count: count, year: reviewYear)
    }

    /// Whether tapping the review row has to switch the view to the year it talks about first.
    var reviewSwitchesYear: Bool { reviewYear != selectedYear }

    // MARK: - The card and the button

    var action: Action { state == .newAccount ? .record : .share(year: reviewYear) }

    var actionTitle: String {
        switch action {
        case .record: String(localized: "Record your first video")
        case .share(let year): String(localized: "Share my \(String(year)) universe")
        }
    }

    /// The card on a sealed year: "2025 · YOUR YEAR", "41 videos · TikTok was your main planet", "Best month October · 9-week streak".
    var yearCard: (eyebrow: String, title: String, detail: String)? {
        guard isSealed else { return nil }
        let stats = YearStats(videos: videos, year: selectedYear, topics: topics, calendar: calendar)
        let eyebrow = String(localized: "\(String(selectedYear)) · YOUR YEAR")
        let title: String
        if let main = stats.mainPlatform {
            title = String(localized: "\(stats.total) videos · \(main.platform.label) was your main planet")
        } else {
            title = String(localized: "\(stats.total) videos")
        }
        var parts: [String] = []
        if let month = stats.bestMonth, let name = Self.monthName(month, calendar: calendar) { parts.append(String(localized: "Best month \(name)")) }
        if stats.longestStreakWeeks > 0 { parts.append(String(localized: "\(stats.longestStreakWeeks)-week streak")) }
        return (eyebrow, title, parts.joined(separator: " · "))
    }

    /// "October", in the language of the interface.
    static func monthName(_ month: Int, calendar: Calendar) -> String? {
        calendar.date(from: DateComponents(year: 2001, month: month, day: 1))?.formatted(.dateTime.month(.wide).locale(.interface))
    }
}
