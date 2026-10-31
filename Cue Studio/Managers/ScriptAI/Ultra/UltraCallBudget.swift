//
//  UltraCallBudget.swift
//  Cue Studio
//

import Foundation

/// The lab's cap on Gemini calls from this iPhone: each call is counted before it goes out, failures included, and none goes out past the limit.
/// A guard for the experiment the owner authorized (1,000 calls, 31/10/2026), never a credit system: the production one has to be the server's
/// (purchases verified there, balances and idempotent operations kept there). The count lives in the app's standard defaults whatever suite a
/// UI test uses, so a test run can't reset it, and nothing here ever lowers it.
@MainActor
@Observable
final class UltraCallBudget {
    static let key = "ultraLab.sdkCalls.v1"
    /// Authorized by the owner on 29/10/2026: 10 in the first checkpoint, then 30, then 80 for the quality comparison with Apple Intelligence,
    /// then "test and improve it as much as it takes" (the lab's Cloud credits are for that): 300; on 31/10/2026, for measuring what scripts
    /// cost in every language and making them cheaper without losing quality, "eu autorizo mais limite" (about USD 258 of credits left): 1,000,
    /// at most about USD 23 at 2.3 cents a call. A guard against a runaway loop.
    static let labLimit = 1_000

    let limit: Int
    private(set) var used: Int
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, limit: Int = UltraCallBudget.labLimit) {
        self.defaults = defaults
        self.limit = limit
        used = defaults.integer(forKey: Self.key)
    }

    var remaining: Int { max(0, limit - used) }

    /// Whether `calls` more can go out.
    func allows(_ calls: Int) -> Bool { remaining >= calls }

    /// Counts one call about to go out; false (nothing counted) when the cap is reached.
    func reserve() -> Bool {
        // Read again: another screen of the app may have counted since.
        used = max(used, defaults.integer(forKey: Self.key))
        guard used < limit else { return false }
        used += 1
        defaults.set(used, forKey: Self.key)
        return true
    }
}
