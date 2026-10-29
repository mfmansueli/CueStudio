//
//  UltraCallBudget.swift
//  Cue Studio
//

import Foundation

/// The lab's cap on Gemini calls from this iPhone: each call is counted before it goes out, failures included, and none goes out past the limit.
/// A guard for the experiment the owner authorized (30 calls, 29/10/2026), never a credit system: the production one has to be the server's
/// (purchases verified there, balances and idempotent operations kept there). The count lives in the app's standard defaults whatever suite a
/// UI test uses, so a test run can't reset it, and nothing here ever lowers it.
@MainActor
@Observable
final class UltraCallBudget {
    static let key = "ultraLab.sdkCalls.v1"
    /// Authorized by the owner on 29/10/2026 (it was 10 in the first checkpoint).
    static let labLimit = 30

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
