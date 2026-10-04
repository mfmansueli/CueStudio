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

    private(set) var sharedTakeIDs: Set<UUID>
    private(set) var firstShareDate: Date?
    private(set) var celebrated: Set<Int>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sharedTakeIDs = Set((defaults.stringArray(forKey: DefaultsKey.sharedTakeIDs) ?? []).compactMap(UUID.init(uuidString:)))
        firstShareDate = defaults.object(forKey: DefaultsKey.firstShareDate) as? Date
        celebrated = Set(defaults.array(forKey: DefaultsKey.celebratedMilestones) as? [Int] ?? [])
    }

    var shares: Int { sharedTakeIDs.count }

    /// Counts a video as shared. Returns the milestone this brought the creator to, once: nil when the video
    /// was counted before or no milestone was reached.
    @discardableResult
    func recordShare(of takeID: UUID, at date: Date = .now) -> Int? {
        guard !sharedTakeIDs.contains(takeID) else { return nil }
        sharedTakeIDs.insert(takeID)
        if firstShareDate == nil { firstShareDate = date }
        defaults.set(sharedTakeIDs.map(\.uuidString), forKey: DefaultsKey.sharedTakeIDs)
        defaults.set(firstShareDate, forKey: DefaultsKey.firstShareDate)
        guard Self.steps.contains(shares), !celebrated.contains(shares) else { return nil }
        return shares
    }

    func markCelebrated(_ milestone: Int) {
        celebrated.insert(milestone)
        defaults.set(Array(celebrated), forKey: DefaultsKey.celebratedMilestones)
    }

    /// The share count of the next milestone, nil after the last.
    var nextMilestone: Int? { Self.steps.first { $0 > shares } }

    /// How far the creator is between the milestone before and the next one (0...1).
    var progress: Double {
        guard let next = nextMilestone else { return 1 }
        let previous = Self.steps.last { $0 <= shares } ?? 0
        return Double(shares - previous) / Double(next - previous)
    }

    func isUnlocked(_ icon: AppIconChoice) -> Bool { shares >= icon.milestone }
}
