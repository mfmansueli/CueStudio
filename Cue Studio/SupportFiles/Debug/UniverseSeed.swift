//
//  UniverseSeed.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// What `-uiTestUniverse <sample|newYear|newAccount>` puts in "Your universe" before the app starts (`09` 9.2, the board's APP DATA panel):
/// **sample** is 23 videos shared in the live year (TikTok 12, Reels 6, Shorts 5) and 41 in the year before (24, 11, 6); **newYear** only the year
/// before; **newAccount** nothing. The creator has three topics. Never shipped.
enum UniverseSeed {
    enum Kind: String {
        case sample, newYear, newAccount
    }

    static func apply(_ kind: Kind, to defaults: UserDefaults, now: Date = .now, calendar: Calendar = .current) {
        var profile = CreatorProfile(name: "Maya Costa", handle: "mayacooks", role: .personal)
        profile.niches = [.finance]
        profile.customTopics = ["Morning routines", "Travel"]
        // Enough of My Cue Voice for the card to be the one of the board (the meter, the sentence, the next question).
        profile.confirmedVoiceSteps = [.audience, .tone]
        profile.audienceLevel = .new
        defaults.set(try? JSONEncoder().encode(profile), forKey: DefaultsKey.creatorProfile)
        guard kind != .newAccount else { return }
        let year = calendar.component(.year, from: now)
        var records: [ShareRecord] = []
        if kind == .sample { records += make(year: year, counts: [(.tiktok, 12), (.reels, 6), (.shorts, 5)], now: now, calendar: calendar) }
        records += make(year: year - 1, counts: [(.tiktok, 24), (.reels, 11), (.shorts, 6)], now: now, calendar: calendar)
        defaults.set(try? JSONEncoder().encode(records), forKey: DefaultsKey.shareRecords)
        defaults.set(records.compactMap(\.date).min(), forKey: DefaultsKey.firstShareDate)
    }

    /// The videos of a year, spread over its months (the live year only up to today), with the topics taking turns.
    private static func make(year: Int, counts: [(Platform, Int)], now: Date, calendar: Calendar) -> [ShareRecord] {
        // The board's legend: Morning routines 12, Finance 7, Travel 4 of 23 (the year before takes turns).
        let live = calendar.component(.year, from: now) == year
        let plan = Array(repeating: "custom.morning routines", count: 12) + Array(repeating: "niche.finance", count: 7)
            + Array(repeating: "custom.travel", count: 4)
        let topics = live ? plan : ["custom.morning routines", "niche.finance", "custom.travel"]
        let lastMonth = live ? calendar.component(.month, from: now) : 12
        var records: [ShareRecord] = []
        var index = 0
        for (platform, count) in counts {
            for _ in 0..<count {
                let month = 1 + index % lastMonth
                let day = live && month == lastMonth ? max(1, calendar.component(.day, from: now) - index % 3) : 3 + (index * 5) % 24
                let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? now
                records.append(ShareRecord(takeID: UUID(), date: date, platforms: [platform], topic: topics[index % topics.count]))
                index += 1
            }
        }
        return records
    }
}
#endif
