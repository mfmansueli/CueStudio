//
//  ProfileUniverseSummary.swift
//  Cue Studio
//

import Foundation

/// The "Your universe" row of the Profile and the line under it (9.1): "2026 · 3 topics", "23 videos", "2 more videos to your next milestone." and
/// its two empty states: a new account ("0 videos", "Starts with your first share") and a new year ("0 videos", "2026 · 23 videos", the year before).
nonisolated struct ProfileUniverseSummary: Equatable, Sendable {
    /// Videos shared, ever, and in the year that is live; and how many the latest earlier year has.
    let total: Int
    let sharedThisYear: Int
    let year: Int
    let lastYear: Int
    let lastYearCount: Int
    let topics: Int
    /// How many more videos to the next milestone; nil after the last.
    let toNextMilestone: Int?

    /// The year has begun and nothing has been shared in it yet, though earlier years have videos.
    var isNewYear: Bool { total > 0 && sharedThisYear == 0 }
    var isNewAccount: Bool { total == 0 }

    /// The trailing count: "23 videos" (this year's), or "0 videos".
    var trailing: String {
        let count = isNewAccount || isNewYear ? 0 : sharedThisYear
        return String(localized: "\(count) videos")
    }

    /// The row's second line.
    var detail: String {
        if isNewAccount { return String(localized: "Starts with your first share") }
        if isNewYear { return String(localized: "\(String(lastYear)) · \(lastYearCount) videos") }
        return String(localized: "\(String(year)) · \(topics) topics")
    }

    /// Under the row.
    var footer: String {
        if isNewAccount { return String(localized: "Share a video to light your first star.") }
        if isNewYear { return String(localized: "Your \(String(year)) universe starts with your first share.") }
        guard let toNextMilestone else { return String(localized: "Every milestone is behind you") }
        return String(localized: "\(toNextMilestone) more videos to your next milestone.")
    }
}
