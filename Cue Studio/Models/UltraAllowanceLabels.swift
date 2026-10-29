//
//  UltraAllowanceLabels.swift
//  Cue Studio
//

import Foundation

/// Ultra AI's scripts left (`UltraAllowance`), as each place says it: the writer chip's menu, the permission sheet and the Profile's plan card. The
/// free scripts are counted "4 of 5"; Pro's month says what is left this month.
nonisolated enum UltraAllowanceLabels {
    /// The writer chip's menu: "Ultra AI · 4 of 5 free left", "Ultra AI · 28 left this month".
    static func menu(_ allowance: UltraAllowance) -> String {
        allowance.membership == .paid
            ? String(localized: "Ultra AI · \(allowance.left) left this month")
            : String(localized: "Ultra AI · \(allowance.freeLeft) of \(UsagePolicy.freeUltraScripts) free left")
    }

    /// Under the permission sheet's title.
    static func consent(_ allowance: UltraAllowance) -> String {
        if allowance.membership == .paid { return String(localized: "\(allowance.left) scripts left this month.") }
        if allowance.freeLeft == UsagePolicy.freeUltraScripts {
            return String(localized: "Your first \(UsagePolicy.freeUltraScripts) scripts are free.")
        }
        return String(localized: "\(allowance.freeLeft) of \(UsagePolicy.freeUltraScripts) free scripts left.")
    }

    /// The Profile's plan card, in its mono line.
    static func plan(_ allowance: UltraAllowance) -> String {
        allowance.membership == .paid
            ? String(localized: "ULTRA AI · \(allowance.left) LEFT THIS MONTH")
            : String(localized: "ULTRA AI · \(allowance.freeLeft) OF \(UsagePolicy.freeUltraScripts) FREE LEFT")
    }
}
