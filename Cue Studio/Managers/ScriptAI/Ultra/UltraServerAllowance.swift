//
//  UltraServerAllowance.swift
//  Cue Studio
//

import Foundation

/// What Cue's server says the creator has left (`{"action": "allowance"}` on the `ultra` function). `metering` is the server's mode: "off"
/// counts nothing, "observe" counts without refusing (the creator still sees this iPhone's count), "enforce" refuses past it (its count is the
/// one shown). `paused`: Cue's spend for the day reached its budget, so Ultra AI rests until the next day (UTC).
nonisolated struct UltraServerAllowance: Codable, Equatable, Sendable {
    var metering: String
    var paused: Bool?
    var membership: String?
    var freeLeft: Int?
    var monthLeft: Int?
    var left: Int?
    var freeTotal: Int?
    var monthTotal: Int?

    /// The server's count as the app's allowance, or nil when the server doesn't enforce one.
    var allowance: UltraAllowance? {
        guard metering == "enforce", let freeLeft, let monthLeft, let freeTotal else { return nil }
        let membership: UltraAllowance.Membership = membership == "pro" ? .paid : .free
        let monthUsed = membership == .paid ? max(0, (monthTotal ?? UsagePolicy.proUltraScriptsPerMonth) - monthLeft) : 0
        return UltraAllowance(
            membership: membership, freeUsed: max(0, freeTotal - freeLeft), monthUsed: monthUsed,
            bonus: max(0, freeTotal - UsagePolicy.freeUltraScripts)
        )
    }
}
