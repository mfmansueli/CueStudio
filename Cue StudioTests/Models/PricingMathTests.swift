//
//  PricingMathTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("PricingMath")
struct PricingMathTests {
    @Test func annualSavingsAgainstTwelveMonths() {
        #expect(PricingMath.savingsPercent(monthlyPrice: Decimal(string: "7.99")!, yearlyPrice: Decimal(string: "39.99")!) == 58)
    }

    @Test func noSavingsWhenYearlyIsNotCheaper() {
        #expect(PricingMath.savingsPercent(monthlyPrice: 5, yearlyPrice: 60) == nil)
        #expect(PricingMath.savingsPercent(monthlyPrice: 0, yearlyPrice: 10) == nil)
    }

    @Test func monthlyEquivalentDividesByTwelve() {
        #expect(PricingMath.monthlyEquivalent(ofYearly: 36) == 3)
    }
}
