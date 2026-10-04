//
//  PaywallCopy.swift
//  Cue Studio
//

import Foundation

/// Paywall wording. Kept free of StoreKit types so it can be tested; prices come in as display strings.
nonisolated enum PaywallCopy {
    static func title(for context: PaywallContext) -> String {
        switch context {
        case .export: String(localized: "Keep posting with Cue")
        case .profile: String(localized: "Take your universe further.")
        }
    }

    static func subtitle(for context: PaywallContext) -> String {
        switch context {
        case .export:
            String(localized: "You've used your \(UsagePolicy.freeExports) free exports. Every feature stays open — start 7 days free to keep exporting. Your takes are safe.")
        case .profile:
            String(localized: "Everything in Cue is free while you try it — \(UsagePolicy.freeExports) exports included. After that, 7 days free, then monthly or annual.")
        }
    }

    /// Only what Pro actually changes: exporting. Every feature is open on the free plan too.
    static let features: [String] = [
        String(localized: "Unlimited video exports, up to 4K"),
        String(localized: "Every feature stays open: AI, My Cue Voice, Quick edit, Clean Up, captions"),
        String(localized: "Your takes are always yours — nothing is ever locked or deleted"),
        String(localized: "Every milestone app icon"),
    ]

    /// The icon and the mono tag of each line of `features`.
    static let featureImages = ["square.and.arrow.up", "sparkles", "lock.open", "sparkle"]
    static let featureTags = [String(localized: "Export"), String(localized: "Free"), String(localized: "Yours"), String(localized: "Universe")]

    /// The lines for this iPhone: the one about AI stays out where Apple Intelligence can't run, so the paywall never
    /// sells what the device cannot do.
    static func visibleFeatureIndices(aiIsAvailable: Bool) -> [Int] {
        features.indices.filter { aiIsAvailable || $0 != 1 }
    }

    static func welcome(for context: PaywallContext, startedTrial: Bool) -> String {
        switch context {
        case .export:
            if startedTrial {
                String(localized: "Trial started — exporting now")
            } else {
                String(localized: "Welcome to Cue Pro — exporting now")
            }
        case .profile:
            if startedTrial {
                String(localized: "Trial started — enjoy Cue Pro")
            } else {
                String(localized: "Welcome to Cue Pro")
            }
        }
    }

    static func price(for plan: ProPlan, displayPrice: String?) -> String {
        let price = displayPrice ?? "…"
        return switch plan {
        case .annual: String(localized: "\(price) / year")
        case .monthly: String(localized: "\(price) / month")
        }
    }

    static func detail(for plan: ProPlan, monthlyEquivalent: String?, trialDays: Int?) -> String {
        switch plan {
        case .annual:
            let perMonth = monthlyEquivalent.map { String(localized: "\($0)/mo") }
            let trial = trialDays.map { String(localized: "\($0) days free") }
            return [perMonth, trial].compactMap { $0 }.joined(separator: " · ")
        case .monthly:
            guard let trialDays else { return String(localized: "Cancel anytime") }
            return String(localized: "\(trialDays) days free · cancel anytime")
        }
    }

    static func callToAction(for plan: ProPlan, displayPrice: String?, trialDays: Int?) -> String {
        if let trialDays { return String(localized: "Start \(trialDays)-day free trial") }
        let price = displayPrice ?? "…"
        return switch plan {
        case .annual: String(localized: "Subscribe for \(price)/year")
        case .monthly: String(localized: "Subscribe for \(price)/month")
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
            if let trialDays {
                return String(localized: "Free for \(trialDays) days, then \(price)/month. Cancel anytime in Settings.")
            }
            return String(localized: "Renews monthly at \(price). Cancel anytime in Settings.")
        }
    }

    static func savingsBadge(percent: Int?) -> String? {
        guard let percent, percent > 0 else { return nil }
        return String(localized: "SAVE \(percent)%")
    }
}
