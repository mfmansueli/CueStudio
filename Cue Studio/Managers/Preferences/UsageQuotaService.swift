//
//  UsageQuotaService.swift
//  Cue Studio
//

import Foundation

/// Counts the one thing the free plan limits: video exports (saving to Photos or sharing). The
/// count lives in the Keychain so a reinstall doesn't reset it.
@MainActor
@Observable
final class UsageQuotaService {
    private(set) var exportsUsed: Int

    private let counter: ExportCountStoring
    private let defaults: UserDefaults

    init(counter: ExportCountStoring = KeychainExportCountStore(), defaults: UserDefaults = .standard) {
        self.counter = counter
        self.defaults = defaults
        exportsUsed = counter.load()
        migrateCountFromDefaults()
        removeLegacyAICounters()
    }

    // MARK: - Reading

    /// Nil means unlimited.
    func exportsLeft(for tier: MembershipTier) -> Int? {
        UsagePolicy.exportLimit(for: tier).map { max(0, $0 - exportsUsed) }
    }

    func canExport(tier: MembershipTier) -> Bool {
        (exportsLeft(for: tier) ?? 1) > 0
    }

    // MARK: - Recording usage

    /// Only the free plan counts exports.
    func recordExport(tier: MembershipTier) {
        guard UsagePolicy.exportLimit(for: tier) != nil else { return }
        exportsUsed += 1
        counter.save(exportsUsed)
    }

    // MARK: - Private

    /// Earlier builds kept the count in UserDefaults; it moves to the Keychain without handing back
    /// exports already used.
    private func migrateCountFromDefaults() {
        let legacy = defaults.integer(forKey: DefaultsKey.legacyCleanExportsUsed)
        guard defaults.object(forKey: DefaultsKey.legacyCleanExportsUsed) != nil else { return }
        if legacy > exportsUsed {
            exportsUsed = legacy
            counter.save(legacy)
        }
        defaults.removeObject(forKey: DefaultsKey.legacyCleanExportsUsed)
    }

    /// v1 metered AI scripts per month; those counters are never read again.
    private func removeLegacyAICounters() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(DefaultsKey.legacyAIScriptsUsedPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
