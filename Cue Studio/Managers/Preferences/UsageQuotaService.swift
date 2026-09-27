//
//  UsageQuotaService.swift
//  Cue Studio
//

import Foundation

/// Counts what the free plan meters: clean exports, for the life of the install.
@MainActor
@Observable
final class UsageQuotaService {
    private(set) var cleanExportsUsed: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        cleanExportsUsed = defaults.integer(forKey: DefaultsKey.cleanExportsUsed)
        removeLegacyAICounters()
    }

    // MARK: - Reading

    /// Nil means unlimited.
    func cleanExportsLeft(for tier: MembershipTier) -> Int? {
        UsagePolicy.cleanExportLimit(for: tier).map { max(0, $0 - cleanExportsUsed) }
    }

    func canExportClean(tier: MembershipTier) -> Bool {
        (cleanExportsLeft(for: tier) ?? 1) > 0
    }

    // MARK: - Recording usage

    /// Only the free plan counts clean exports.
    func recordCleanExport(tier: MembershipTier) {
        guard UsagePolicy.cleanExportLimit(for: tier) != nil else { return }
        cleanExportsUsed += 1
        defaults.set(cleanExportsUsed, forKey: DefaultsKey.cleanExportsUsed)
    }

    // MARK: - Private

    /// v1 metered AI scripts per month; those counters are never read again.
    private func removeLegacyAICounters() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(DefaultsKey.legacyAIScriptsUsedPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
