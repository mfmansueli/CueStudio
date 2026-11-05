//
//  UltraAllowanceService.swift
//  Cue Studio
//

import Foundation

/// Ultra AI's allowance as the creator sees it: the free scripts, those invites earned on Pro, and Pro's monthly ones. This iPhone keeps its own
/// count in UserDefaults (a reinstall clears it, anyone can edit it): **not a protection of credits**. Cue's server keeps the real one
/// (`ultraMetering`, DESIGN_PROJECT §57) and refuses past it; while the server enforces it, its answer (`server`) is what shows. A script is
/// counted once it is written (polished); a failed or stopped one isn't. Pro's month is the calendar month (UTC on the server).
@MainActor
@Observable
final class UltraAllowanceService {
    static let freeUsedKey = "ultraPreview.freeUsed.v1"
    static let monthKey = "ultraPreview.month.v1"
    static let monthUsedKey = "ultraPreview.monthUsed.v1"

    private var freeUsed: Int
    private var monthUsed: Int
    /// The month `monthUsed` counts ("2026-10").
    private var month: String
    /// Scripts the creator's invites earned on Pro (`ReferralService`).
    var bonusScripts = 0
    /// Cue's server's count, while it enforces one (`UltraScriptService.refreshAllowance`); nil shows this iPhone's.
    var server: UltraAllowance?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let membership: @MainActor () -> UltraAllowance.Membership
    @ObservationIgnored private let now: () -> Date

    /// - Parameter membership: the creator's plan now (`StoreManager`), read each time (it changes with a purchase or an expiry).
    init(defaults: UserDefaults, membership: @escaping @MainActor () -> UltraAllowance.Membership, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.membership = membership
        self.now = now
        freeUsed = defaults.integer(forKey: Self.freeUsedKey)
        monthUsed = defaults.integer(forKey: Self.monthUsedKey)
        month = defaults.string(forKey: Self.monthKey) ?? ""
    }

    var allowance: UltraAllowance { server ?? local }

    private var local: UltraAllowance {
        UltraAllowance(
            membership: membership(), freeUsed: freeUsed, monthUsed: month == Self.monthID(now()) ? monthUsed : 0, bonus: bonusScripts
        )
    }

    var left: Int { allowance.left }

    /// One script was written.
    func spend() {
        server = server?.spending()
        let next = local.spending()
        freeUsed = next.freeUsed
        monthUsed = next.monthUsed
        month = Self.monthID(now())
        defaults.set(freeUsed, forKey: Self.freeUsedKey)
        defaults.set(monthUsed, forKey: Self.monthUsedKey)
        defaults.set(month, forKey: Self.monthKey)
    }

    /// The lab's "Give the free scripts back": every free script back, to see the first use again. Never the lab's call count (`UltraCallBudget`).
    func resetPreview() {
        server = nil
        freeUsed = 0
        monthUsed = 0
        for key in [Self.freeUsedKey, Self.monthUsedKey, Self.monthKey] { defaults.removeObject(forKey: key) }
    }

    /// Sets how many free scripts are left: the UI tests (`-uiTestUltraScriptsLeft`), and the lab's "Use up the free scripts" (the used-up Pro
    /// without spending test calls).
    func setFreeLeft(_ left: Int) {
        server = nil
        freeUsed = max(0, UsagePolicy.freeUltraScripts + bonusScripts - left)
        defaults.set(freeUsed, forKey: Self.freeUsedKey)
    }

    private static func monthID(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }
}
