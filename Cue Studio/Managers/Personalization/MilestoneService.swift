//
//  MilestoneService.swift
//  Cue Studio
//

import Foundation

/// How many videos the creator has shared, kept on this iPhone, and the milestones that count opens (1, 10, 25 and
/// 50 shared). A video counts once, however many times it is shared.
@MainActor
@Observable
final class MilestoneService {
    /// The share counts that open an icon.
    static let steps = [1, 10, 25, 50]

    /// Every video shared, once each, oldest first.
    private(set) var records: [ShareRecord]
    private(set) var firstShareDate: Date?
    private(set) var celebrated: Set<Int>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var records = defaults.data(forKey: DefaultsKey.shareRecords).flatMap { try? JSONDecoder().decode([ShareRecord].self, from: $0) } ?? []
        // The videos counted before records existed keep counting, with only their take to say when and where.
        let known = Set(records.map(\.takeID))
        let legacy = (defaults.stringArray(forKey: DefaultsKey.sharedTakeIDs) ?? []).compactMap(UUID.init(uuidString:)).filter { !known.contains($0) }
        records += legacy.map { ShareRecord(takeID: $0, date: nil, topic: nil) }
        self.records = records
        firstShareDate = defaults.object(forKey: DefaultsKey.firstShareDate) as? Date
        celebrated = Set(defaults.array(forKey: DefaultsKey.celebratedMilestones) as? [Int] ?? [])
    }

    var sharedTakeIDs: Set<UUID> { Set(records.map(\.takeID)) }

    /// Videos shared, ever. Icons stay unlocked once this reaches their step.
    var shares: Int { records.count }

    /// Videos shared in the live year: the milestones are counted in it ("23 / 25", "25 videos in 2026"), so each year has its own road.
    var yearShares: Int { shares(in: UniverseYears.current()) }

    func shares(in year: Int, calendar: Calendar = .current) -> Int {
        records.filter { calendar.component(.year, from: $0.date ?? firstShareDate ?? .now) == year }.count
    }

    /// Counts a video as shared, and adds `platform` to the networks it went to (a video counts once; each network adds one to its planet).
    /// Returns the milestone this brought the creator to in the live year, once: nil when the video was counted before, no milestone was reached,
    /// or the icon it opens was already won in an earlier year.
    @discardableResult
    func recordShare(of takeID: UUID, at date: Date = .now, platform: Platform? = nil, topic: String? = nil) -> Int? {
        if let index = records.firstIndex(where: { $0.takeID == takeID }) {
            // Counted before: a new network is still a new star on its planet.
            if let platform, !records[index].platforms.contains(platform) {
                records[index].platforms.append(platform)
                persist()
            }
            return nil
        }
        records.append(ShareRecord(takeID: takeID, date: date, platforms: platform.map { [$0] } ?? [], topic: topic))
        if firstShareDate == nil { firstShareDate = date }
        persist()
        let year = Calendar.current.component(.year, from: date)
        let count = shares(in: year)
        let alreadyWon = shares - 1 >= count
        guard Self.steps.contains(count), !alreadyWon, !celebrated.contains(Self.key(count, in: year)) else { return nil }
        return count
    }

    private static func key(_ milestone: Int, in year: Int) -> Int { year * 1000 + milestone }

    private func persist() {
        defaults.set(sharedTakeIDs.map(\.uuidString), forKey: DefaultsKey.sharedTakeIDs)
        defaults.set(try? JSONEncoder().encode(records), forKey: DefaultsKey.shareRecords)
        defaults.set(firstShareDate, forKey: DefaultsKey.firstShareDate)
    }

    /// The videos each planet of `year` had when "Your universe" was last open; empty the first time.
    func seenPlanetCounts(year: Int) -> [Platform: Int] {
        let stored = defaults.dictionary(forKey: DefaultsKey.seenPlanetCounts) as? [String: Int] ?? [:]
        var seen: [Platform: Int] = [:]
        for platform in Platform.allCases { if let count = stored["\(year).\(platform.rawValue)"] { seen[platform] = count } }
        return seen
    }

    func markPlanetsSeen(_ counts: [Platform: Int], year: Int) {
        var stored = defaults.dictionary(forKey: DefaultsKey.seenPlanetCounts) as? [String: Int] ?? [:]
        for platform in Platform.allCases { stored["\(year).\(platform.rawValue)"] = counts[platform] ?? 0 }
        defaults.set(stored, forKey: DefaultsKey.seenPlanetCounts)
    }

    func markCelebrated(_ milestone: Int) {
        celebrated.insert(milestone)
        celebrated.insert(Self.key(milestone, in: UniverseYears.current()))
        defaults.set(Array(celebrated), forKey: DefaultsKey.celebratedMilestones)
    }

    /// The next milestone of the live year, nil after the last.
    var nextMilestone: Int? { Self.steps.first { $0 > yearShares } }

    /// How far the live year is between the milestone before and the next one (0...1).
    var progress: Double {
        guard let next = nextMilestone else { return 1 }
        let previous = Self.steps.last { $0 <= yearShares } ?? 0
        return Double(yearShares - previous) / Double(next - previous)
    }

    func isUnlocked(_ icon: AppIconChoice) -> Bool { shares >= icon.milestone }
}
