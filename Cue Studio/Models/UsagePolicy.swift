//
//  UsagePolicy.swift
//  Cue Studio
//

import Foundation

/// Free-plan limits. The teleprompter itself is always free; clean exports and AI scripts are metered.
nonisolated enum UsagePolicy {
    static let freeCleanExports = 5
    static let freeAIScriptsPerMonth = 5
    static let lifetimeAIScriptsPerMonth = 30

    /// Nil means unlimited.
    static func cleanExportLimit(for tier: MembershipTier) -> Int? {
        tier == .free ? freeCleanExports : nil
    }

    /// Nil means unlimited.
    static func aiScriptLimit(for tier: MembershipTier) -> Int? {
        switch tier {
        case .free: freeAIScriptsPerMonth
        case .lifetime: lifetimeAIScriptsPerMonth
        case .subscriber: nil
        }
    }

    /// Identifies the calendar month AI usage is counted in, e.g. "2026-09".
    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        let month = parts.month ?? 1
        return "\(parts.year ?? 0)-" + (month < 10 ? "0\(month)" : "\(month)")
    }
}
