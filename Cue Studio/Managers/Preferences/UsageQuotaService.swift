//
//  UsageQuotaService.swift
//  Cue Studio
//

import Foundation

/// Counts the one thing the free plan limits: video exports (saving to Photos or sharing). The
/// count lives in the Keychain so a reinstall doesn't reset it (Debug builds do, to test the free plan again).
@MainActor
@Observable
final class UsageQuotaService {
    private(set) var exportsUsed: Int

    private let counter: ExportCountStoring
    private let defaults: UserDefaults

    /// `resetsOnNewInstall` (Debug builds, `LaunchOptions`) gives a new install its free exports back.
    init(counter: ExportCountStoring = KeychainExportCountStore(), defaults: UserDefaults = .standard, resetsOnNewInstall: Bool = false) {
        self.counter = counter
        self.defaults = defaults
        exportsUsed = counter.load()
        migrateCountFromDefaults()
        removeLegacyAICounters()
        if resetsOnNewInstall { resetOnNewInstall() }
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

    /// The Keychain keeps the count through a reinstall, which is the point in Release; testing the free plan needs the
    /// five exports back. UserDefaults goes with the app, so a missing marker means this is the install's first launch.
    private func resetOnNewInstall() {
        guard defaults.object(forKey: DefaultsKey.installLaunched) == nil else { return }
        defaults.set(true, forKey: DefaultsKey.installLaunched)
        guard exportsUsed > 0 else { return }
        exportsUsed = 0
        counter.save(0)
    }

    /// v1 metered AI scripts per month; those counters are never read again.
    private func removeLegacyAICounters() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(DefaultsKey.legacyAIScriptsUsedPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
