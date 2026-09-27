//
//  PricingMath.swift
//  Cue Studio
//

import Foundation

/// Price comparisons for the paywall, free of StoreKit types so it can be unit-tested.
nonisolated enum PricingMath {
    /// How much the yearly plan saves over paying monthly for a year, rounded down to a whole percent.
    static func savingsPercent(monthlyPrice: Decimal, yearlyPrice: Decimal) -> Int? {
        let yearOfMonthly = monthlyPrice * 12
        guard yearOfMonthly > 0, yearlyPrice < yearOfMonthly else { return nil }
        let ratio = NSDecimalNumber(decimal: (yearOfMonthly - yearlyPrice) / yearOfMonthly).doubleValue
        return Int((ratio * 100).rounded(.down))
    }

    static func monthlyEquivalent(ofYearly yearlyPrice: Decimal) -> Decimal {
        yearlyPrice / 12
    }
}
