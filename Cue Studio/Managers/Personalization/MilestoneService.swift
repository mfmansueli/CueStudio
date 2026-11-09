//
//  MilestoneService.swift
//  Cue Studio
//

import Foundation

/// How many videos the creator has shared (a post they confirmed with "Yes, it's live"; a copy saved to Photos is not one), kept on this
/// iPhone, and the milestones that count opens (1, 10, 25 and 50 shared in the creator's life, each with its app icon; owner, 30/10/2026). A
/// video counts once, however many times it is shared. The year is the universe's retrospective (`shares(in:)`), never a milestone's road.
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
        // Kept as `year * 1000 + milestone` while the milestones were counted per year: each one is the life's milestone now.
        celebrated = Set((defaults.array(forKey: DefaultsKey.celebratedMilestones) as? [Int] ?? []).map(Self.lifeMilestone))
    }

    var sharedTakeIDs: Set<UUID> { Set(records.map(\.takeID)) }

    /// Videos shared, ever. Icons stay unlocked once this reaches their step.
    var shares: Int { records.count }

    /// Videos shared in the live year, for the universe's look back at it (never a milestone).
    var yearShares: Int { shares(in: UniverseYears.current()) }

    func shares(in year: Int, calendar: Calendar = .current) -> Int {
        records.filter { calendar.component(.year, from: $0.date ?? firstShareDate ?? .now) == year }.count
    }

    /// Counts a video as shared, and adds `platform` to the networks it went to (a video counts once; each network adds one to its planet).
    /// Returns the milestone this brought the creator to, once in their life: nil when the video was counted before, no milestone was
    /// reached, or it was already told.
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
        guard Self.steps.contains(shares), !celebrated.contains(shares) else { return nil }
        return shares
    }

    /// A celebrated key of the per-year days (`year * 1000 + milestone`) as the milestone it was.
    private static func lifeMilestone(_ key: Int) -> Int { key > 1000 ? key % 1000 : key }

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

    /// `milestone` was told (in a send-off): it and every one before it, so an older milestone never pops up after a newer one.
    func markCelebrated(_ milestone: Int) {
        celebrated.formUnion(Self.steps.filter { $0 <= milestone })
        celebrated.insert(milestone)
        defaults.set(Array(celebrated), forKey: DefaultsKey.celebratedMilestones)
    }

    /// The milestone a send-off tells now: the last one the confirmed posts reached and nobody told yet (D4, owner 09/11/2026). Reached
    /// with a post whose send-off didn't play (Celebrations off, Cue closed on it), it is told with the next one.
    var dueMilestone: Int? { Self.steps.last { $0 <= shares && !celebrated.contains($0) } }

    /// The next milestone in the creator's life, nil after the last. Its icon is never one already unlocked.
    var nextMilestone: Int? { Self.steps.first { $0 > shares } }

    /// How far the creator is between the milestone before and the next one (0...1).
    var progress: Double {
        guard let next = nextMilestone else { return 1 }
        let previous = Self.steps.last { $0 <= shares } ?? 0
        return Double(shares - previous) / Double(next - previous)
    }

    func isUnlocked(_ icon: AppIconChoice) -> Bool { shares >= icon.milestone }
}
