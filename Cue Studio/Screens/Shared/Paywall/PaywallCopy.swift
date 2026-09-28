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
        case .creatorVoice: String(localized: "AI that sounds like you")
        case .hookVariations: String(localized: "Hooks that stop the scroll")
        case .platformVersions: String(localized: "One script, every platform")
        case .bestTake: String(localized: "Let Cue pick your best take")
        case .fourK: String(localized: "Post in 4K")
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
        case .creatorVoice:
            String(localized: "Your vocabulary, your style and “In my voice” rewrites are part of Pro. How you sound, your phrases and your niche stay free.")
        case .hookVariations:
            String(localized: "Apple Intelligence writes new hooks for this script with Pro. The quick hook ideas stay free.")
        case .platformVersions:
            String(localized: "Pro rewrites a script for another platform — its length and pace — and saves it as a copy.")
        case .bestTake:
            String(localized: "Pro compares your takes with the script's timing and suggests the one to post.")
        case .fourK:
            String(localized: "4K exports are part of Pro, with unlimited clean exports.")
        }
    }

    /// Only what Pro actually unlocks (the prototype's Apple Watch remote and iPad & Mac sync don't
    /// exist, so they aren't promised).
    static let features: [String] = [
        String(localized: "Unlimited exports, no watermark, up to 4K"),
        String(localized: "Full Creator Voice + sponsored-ad scripts"),
        String(localized: "Hook variations, multi-platform versions, best-take picks"),
    ]

    static func welcome(for context: PaywallContext) -> String {
        switch context {
        case .export: String(localized: "Welcome to Pro — exporting without watermark")
        case .sponsoredAd: String(localized: "Welcome to Pro — sponsored ads unlocked")
        case .creatorVoice: String(localized: "Welcome to Pro — your full voice is on")
        case .fourK: String(localized: "Welcome to Pro — 4K unlocked")
        case .profile, .hookVariations, .platformVersions, .bestTake: String(localized: "Welcome to Cue Pro")
        }
    }

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
