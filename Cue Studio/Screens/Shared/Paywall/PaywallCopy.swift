//
//  PaywallCopy.swift
//  Cue Studio
//

import Foundation

/// Paywall wording. Kept free of StoreKit types so it can be tested; prices come in as display strings.
nonisolated enum PaywallCopy {
    static func title(for context: PaywallContext) -> String {
        switch context {
        case .export: String(localized: "Post without the watermark")
        case .sponsoredAd: String(localized: "Brand deals, done right")
        case .profile: String(localized: "Create more. Sound like you.")
        }
    }

    static func subtitle(for context: PaywallContext) -> String {
        switch context {
        case .export:
            String(localized: "You've used your \(UsagePolicy.freeCleanExports) free clean exports. Your takes are safe — export them clean anytime with Pro.")
        case .sponsoredAd:
            String(localized: "Sponsored-ad scripts with disclosure, offer and brand checklist are part of Pro. Everything else in AI stays free.")
        case .profile:
            String(localized: "The teleprompter stays free forever. Pro unlocks clean exports and AI that knows your style.")
        }
    }

    /// Only what Pro actually unlocks.
    static let features: [String] = [
        String(localized: "Unlimited exports, no watermark, up to 4K"),
        String(localized: "Full Creator Voice + sponsored-ad scripts"),
        String(localized: "Your takes stay yours — export any of them clean"),
    ]

    static func price(for plan: ProPlan, displayPrice: String?) -> String {
        let price = displayPrice ?? "…"
        return switch plan {
        case .annual: String(localized: "\(price) / year")
        case .monthly: String(localized: "\(price) / month")
        case .lifetime: String(localized: "\(price) once")
        }
    }

    static func detail(for plan: ProPlan, monthlyEquivalent: String?, trialDays: Int?) -> String {
        switch plan {
        case .annual:
            let perMonth = monthlyEquivalent.map { String(localized: "\($0)/mo") }
            let trial = trialDays.map { String(localized: "\($0) days free") }
            return [perMonth, trial].compactMap { $0 }.joined(separator: " · ")
        case .monthly:
            return String(localized: "Cancel anytime")
        case .lifetime:
            return String(localized: "Pay once · everything in Pro")
        }
    }

    static func callToAction(for plan: ProPlan, displayPrice: String?, trialDays: Int?) -> String {
        let price = displayPrice ?? "…"
        switch plan {
        case .annual:
            if let trialDays { return String(localized: "Start \(trialDays)-day free trial") }
            return String(localized: "Subscribe for \(price)/year")
        case .monthly:
            return String(localized: "Subscribe for \(price)/month")
        case .lifetime:
            return String(localized: "Buy lifetime for \(price)")
        }
    }

    static func finePrint(for plan: ProPlan, displayPrice: String?, trialDays: Int?) -> String {
        let price = displayPrice ?? "…"
        switch plan {
        case .annual:
            if let trialDays {
                return String(localized: "Free for \(trialDays) days, then \(price)/year. Cancel anytime in Settings.")
            }
            return String(localized: "Renews yearly at \(price). Cancel anytime in Settings.")
        case .monthly:
            return String(localized: "Renews monthly at \(price). Cancel anytime in Settings.")
        case .lifetime:
            return String(localized: "One-time purchase.")
        }
    }

    static func savingsBadge(percent: Int?) -> String? {
        guard let percent, percent > 0 else { return nil }
        return String(localized: "SAVE \(percent)%")
    }
}
