//
//  PaywallCopy.swift
//  Cue Studio
//

import Foundation

/// Paywall wording. Kept free of StoreKit types so it can be tested; prices come in as display strings.
nonisolated enum PaywallCopy {
    static func title(for context: PaywallContext) -> String {
        switch context {
        case .export: String(localized: "Keep sharing your universe.")
        case .profile: String(localized: "Take your universe further.")
        case .ultra: String(localized: "Keep writing with Ultra AI.")
        }
    }

    /// The small line above the title: the plans' name, or (when the video is waiting) that it is ready.
    static func eyebrow(for context: PaywallContext) -> String {
        switch context {
        case .export: String(localized: "YOUR VIDEO IS READY")
        case .profile: String(localized: "CUE PRO")
        case .ultra: String(localized: "ULTRA AI")
        }
    }

    /// - Parameter ultraIsOffered: Ultra AI is offered on this iPhone (its free scripts are part of trying Cue).
    static func subtitle(for context: PaywallContext, ultraIsOffered: Bool = false) -> String {
        switch context {
        case .export:
            String(localized: "Subscribe and export it now.")
        case .profile:
            ultraIsOffered ? freeToTryWithUltra : freeToTry
        case .ultra:
            String(localized: "Your \(UsagePolicy.freeUltraScripts) free scripts are written. Cue Pro adds \(UsagePolicy.proUltraScriptsPerMonth) a month.")
        }
    }

    /// The rest of what Pro offers, under its two highlights (the exports, and Ultra AI's scripts where Ultra AI is offered, `ProHighlightCard`),
    /// in plain lines. Only what Pro really adds today (decision 12, 30/10/2026): My Cue Voice, ad drafts, hook and platform versions, covers,
    /// series tags and "Text behind me" are free for everyone, and nothing free is locked to fill this list. The watermark line says that
    /// exported videos never carry one: only a screen recording or mirroring of Cue does, on the free plan (`CaptureWatermark`).
    static let benefits: [ProBenefit] = [
        ProBenefit(text: String(localized: "The milestone app icons from 10 videos on")),
        ProBenefit(text: String(localized: "No Cue mark on screen recordings · exported videos never have one")),
    ]

    /// The lines for this iPhone: the ones about Apple Intelligence stay out where it can't run, and the ones for what the app cannot do yet stay out
    /// (the Apple Watch and Mac remote), so the paywall never sells what is not there.
    static func visibleBenefits(aiIsAvailable: Bool) -> [ProBenefit] {
        benefits.filter { $0.isAvailable && (aiIsAvailable || !$0.needsAppleIntelligence) }
    }

    /// The line under the title of the regular Pro: trying Cue is its free exports (there is no free trial).
    static var freeToTry: String {
        String(localized: "Free to try · \(UsagePolicy.freeExports) exports included.")
    }

    /// The same, where Ultra AI is offered: its free scripts are part of trying Cue.
    static var freeToTryWithUltra: String {
        String(localized: "Free to try · \(UsagePolicy.freeExports) exports and \(UsagePolicy.freeUltraScripts) Ultra AI scripts included.")
    }

    static func welcome(for context: PaywallContext) -> String {
        switch context {
        case .export: String(localized: "Welcome to Cue Pro · video exported")
        case .profile: String(localized: "Welcome to Cue Pro")
        case .ultra: String(localized: "Welcome to Cue Pro · \(UsagePolicy.proUltraScriptsPerMonth) Ultra AI scripts this month")
        }
    }

    /// "$39.99", or an ellipsis while the price loads.
    static func priceOnly(displayPrice: String?) -> String { displayPrice ?? "…" }

    static func price(for plan: ProPlan, displayPrice: String?) -> String {
        let price = displayPrice ?? "…"
        return switch plan {
        case .annual: String(localized: "\(price) / year")
        case .monthly: String(localized: "\(price) / month")
        }
    }

    static func callToAction(for plan: ProPlan, displayPrice: String?, context: PaywallContext = .profile) -> String {
        if context == .export { return String(localized: "Subscribe · export now") }
        let price = displayPrice ?? "…"
        return switch plan {
        case .annual: String(localized: "Subscribe for \(price)/year")
        case .monthly: String(localized: "Subscribe for \(price)/month")
        }
    }

    static func finePrint(for plan: ProPlan, displayPrice: String?) -> String {
        let price = displayPrice ?? "…"
        return switch plan {
        case .annual: String(localized: "Renews yearly at \(price). Cancel anytime in Settings.")
        case .monthly: String(localized: "Renews monthly at \(price). Cancel anytime in Settings.")
        }
    }

    static func savingsBadge(percent: Int?) -> String? {
        guard let percent, percent > 0 else { return nil }
        return String(localized: "SAVE \(percent)%")
    }
}
