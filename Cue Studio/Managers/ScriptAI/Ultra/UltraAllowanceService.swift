//
//  UltraAllowanceService.swift
//  Cue Studio
//

import Foundation

/// Ultra AI's allowance as a preview on this iPhone (Ultra is in Debug builds only): what a creator would be shown (the free scripts, Pro's monthly
/// ones) so the owner can judge the product before the real one exists. **Not a protection of credits**: the counts live in UserDefaults, which a
/// reinstall clears and anyone can edit. Production keeps them on Cue's server (`reports/ULTRA_AI_NATIVE_2026-10-29.md`, Monetization). A script
/// is counted once it is written (polished); a failed or stopped one isn't. Pro's month is the calendar month here (the App Store's billing
/// period on the server).
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

    var allowance: UltraAllowance {
        UltraAllowance(membership: membership(), freeUsed: freeUsed, monthUsed: month == Self.monthID(now()) ? monthUsed : 0)
    }

    var left: Int { allowance.left }

    /// The first day of next month, when a paid month's scripts come back.
    var renewal: Date {
        Calendar.current.dateInterval(of: .month, for: now())?.end ?? now()
    }

    /// One script was written.
    func spend() {
        let current = allowance
        let next = current.spending()
        freeUsed = next.freeUsed
        monthUsed = next.monthUsed
        month = Self.monthID(now())
        defaults.set(freeUsed, forKey: Self.freeUsedKey)
        defaults.set(monthUsed, forKey: Self.monthUsedKey)
        defaults.set(month, forKey: Self.monthKey)
    }

    /// The lab's "Give the free scripts back": every free script back, to see the first use again. Never the lab's call count (`UltraCallBudget`).
    func resetPreview() {
        freeUsed = 0
        monthUsed = 0
        for key in [Self.freeUsedKey, Self.monthUsedKey, Self.monthKey] { defaults.removeObject(forKey: key) }
    }

    /// Sets how many free scripts are left: the UI tests (`-uiTestUltraScriptsLeft`), and the lab's "Use up the free scripts" (the used-up Pro
    /// without spending test calls).
    func setFreeLeft(_ left: Int) {
        freeUsed = max(0, UsagePolicy.freeUltraScripts - left)
        defaults.set(freeUsed, forKey: Self.freeUsedKey)
    }

    private static func monthID(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }
}
