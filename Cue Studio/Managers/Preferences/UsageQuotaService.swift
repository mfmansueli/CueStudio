//
//  UsageQuotaService.swift
//  Cue Studio
//

import Foundation

/// Counts what the free plan meters: clean exports (lifetime) and AI scripts (per calendar month).
@MainActor
@Observable
final class UsageQuotaService {
    private(set) var cleanExportsUsed: Int
    private(set) var aiScriptsUsedThisMonth: Int

    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        cleanExportsUsed = defaults.integer(forKey: DefaultsKey.cleanExportsUsed)
        aiScriptsUsedThisMonth = defaults.integer(
            forKey: DefaultsKey.aiScriptsUsed(month: UsagePolicy.monthKey(for: now(), calendar: calendar))
        )
        pruneOldMonths()
    }

    // MARK: - Reading

    /// Nil means unlimited.
    func cleanExportsLeft(for tier: MembershipTier) -> Int? {
        UsagePolicy.cleanExportLimit(for: tier).map { max(0, $0 - cleanExportsUsed) }
    }

    /// Nil means unlimited.
    func aiScriptsLeft(for tier: MembershipTier) -> Int? {
        UsagePolicy.aiScriptLimit(for: tier).map { max(0, $0 - aiScriptsUsedThisMonth) }
    }

    func canExportClean(tier: MembershipTier) -> Bool {
        (cleanExportsLeft(for: tier) ?? 1) > 0
    }

    func canGenerateAIScript(tier: MembershipTier) -> Bool {
        (aiScriptsLeft(for: tier) ?? 1) > 0
    }

    // MARK: - Recording usage

    /// Only the free plan counts clean exports.
    func recordCleanExport(tier: MembershipTier) {
        guard UsagePolicy.cleanExportLimit(for: tier) != nil else { return }
        cleanExportsUsed += 1
        defaults.set(cleanExportsUsed, forKey: DefaultsKey.cleanExportsUsed)
    }

    func recordAIScript(tier: MembershipTier) {
        guard UsagePolicy.aiScriptLimit(for: tier) != nil else { return }
        refreshMonth()
        aiScriptsUsedThisMonth += 1
        defaults.set(aiScriptsUsedThisMonth, forKey: currentMonthKey)
    }

    /// Re-reads the counter for the current month; call when the app returns to the foreground.
    func refreshMonth() {
        aiScriptsUsedThisMonth = defaults.integer(forKey: currentMonthKey)
    }

    // MARK: - Private

    private var currentMonthKey: String {
        DefaultsKey.aiScriptsUsed(month: UsagePolicy.monthKey(for: now(), calendar: calendar))
    }

    /// Old monthly counters are never read again.
    private func pruneOldMonths() {
        let current = currentMonthKey
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(DefaultsKey.aiScriptsUsedPrefix) && key != current {
            defaults.removeObject(forKey: key)
        }
    }
}
